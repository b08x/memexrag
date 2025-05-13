# frozen_string_literal: true

module MemexRAG
  module Processors
    class Multilingual
      TA_SENTENCE_MODEL = 'xx_sent_ud_sm'
      TA_NER_MODEL = 'xx_ent_wiki_sm'
      ENG_MODEL = 'en_core_web_trf' # Same as SpacyNLP uses

      attr_reader :en_nlp, :ta_nlp_sents, :ta_nlp_ner, :initialization_error_message

      class << self
        def instance
          @instance ||= new
        end
      end

      def process_english(text_or_texts, batch_size: 50)
        return handle_initialization_error('English processing error') if @initialization_error_message
        return handle_model_not_loaded_error(@en_nlp, 'English model (@en_nlp) not available.', 'English processing error') unless @en_nlp

        if text_or_texts.is_a?(Array)
          process_english_batch(text_or_texts, batch_size)
        else
          process_single_english_text(text_or_texts)
        end
      rescue StandardError => e
        handle_processing_error(e, 'English processing error')
      end

      def process_tamil(text_or_texts, batch_size: 50)
        return handle_initialization_error('Tamil processing error') if @initialization_error_message

        unless @ta_nlp_sents && @ta_nlp_ner
          models_missing = []
          models_missing << 'Tamil sentence model' unless @ta_nlp_sents
          models_missing << 'Tamil NER model' unless @ta_nlp_ner
          return handle_model_not_loaded_error(nil, "#{models_missing.join(' and ')} not available.", 'Tamil processing error')
        end

        if text_or_texts.is_a?(Array)
          process_tamil_batch(text_or_texts, batch_size)
        else
          process_single_tamil_text(text_or_texts)
        end
      rescue StandardError => e
        handle_processing_error(e, 'Tamil processing error')
      end

      private

      def initialize
        @initialization_error_message = nil
        begin
          # All models are now fetched from the central registry
          @en_nlp = SpacyModelRegistry.get_model(ENG_MODEL)
          @ta_nlp_sents = SpacyModelRegistry.get_model(TA_SENTENCE_MODEL)
          @ta_nlp_ner = SpacyModelRegistry.get_model(TA_NER_MODEL)
        rescue StandardError => e
          # If any model fails to load from the registry, store the error message.
          # The processing methods will check this.
          @initialization_error_message = "Failed to initialize one or more spaCy models via registry: #{e.message}"
          warn "[MemexRAG::Processors::Multilingual] #{@initialization_error_message}"
          # Depending on desired resilience, you might want specific fallbacks
          # if only some models load. For now, any failure blocks all.
        end
      end

      def handle_initialization_error(context)
        error_info = {
          error: true,
          message: "#{context}: Initialization failed due to: #{@initialization_error_message}",
          sentences: [],
          entities: []
        }
        warn error_info[:message] # Log it
        error_info
      end

      def handle_model_not_loaded_error(_model_instance, specific_message, context)
        # This method is a helper in case a model instance variable is unexpectedly nil
        # even if no @initialization_error_message was set (e.g. logic error).
        message = @initialization_error_message || specific_message
        error_info = {
          error: true,
          message: "#{context}: #{message}",
          sentences: [],
          entities: []
        }
        warn error_info[:message] # Log it
        error_info
      end

      # process_english_batch, process_single_english_text, extract_english_data,
      # process_tamil_batch, process_single_tamil_text, handle_processing_error
      # remain the same as they operate on the instance variables.
      # Ensure they correctly use @en_nlp, @ta_nlp_sents, @ta_nlp_ner

      def process_english_batch(texts, batch_size)
        docs = @en_nlp.pipe(texts, batch_size: batch_size)
        docs.map { |doc| extract_english_data(doc) }
      end

      def process_single_english_text(text)
        doc = @en_nlp.read(text)
        extract_english_data(doc)
      end

      def extract_english_data(doc)
        {
          sentences: doc.sents.map(&:text),
          entities: doc.ents.map { |ent| { text: ent.text, label: ent.label_ } }
        }
      end

      def process_tamil_batch(texts, batch_size)
        sent_docs = @ta_nlp_sents.pipe(texts, batch_size: batch_size)
        ner_docs = @ta_nlp_ner.pipe(texts, batch_size: batch_size)
        sent_docs.zip(ner_docs).map do |sent_doc, ner_doc|
          {
            sentences: sent_doc.sents.map(&:text),
            entities: ner_doc.ents.map { |ent| { text: ent.text, label: ent.label_ } }
          }
        end
      end

      def process_single_tamil_text(text)
        sent_doc = @ta_nlp_sents.read(text)
        ner_doc = @ta_nlp_ner.read(text)
        {
          sentences: sent_doc.sents.map(&:text),
          entities: ner_doc.ents.map { |ent| { text: ent.text, label: ent.label_ } }
        }
      end

      def handle_processing_error(error, context)
        # Ensure this logs sufficiently or propagates errors as needed.
        # The original implementation used `puts` if Rails.logger wasn't available.
        message_text = "#{context}: #{error.message}"
        log_details = "#{message_text}\n#{error.backtrace.join("\n")}"

        if defined?(Rails) && Rails.logger
          Rails.logger.error log_details
        else
          warn log_details # Use warn for stderr
        end

        {
          error: true,
          message: message_text,
          sentences: [],
          entities: []
        }
      end
    end
  end
end
