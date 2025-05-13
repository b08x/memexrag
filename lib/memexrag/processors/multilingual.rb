# frozen_string_literal: true

# Configure multilingual NLP pipeline
# This module provides efficient NLP processing for English and Tamil texts
# using a singleton pattern to avoid repeated model initialization.

# Constants for model names

module MemexRAG
  module Processors
    # Multilingual class for NLP processing in English and Tamil
    # Implements singleton pattern to avoid repeated model loading
    # and provides optimized processing methods for sentence segmentation and NER
    class Multilingual
      TA_SENTENCE_MODEL = 'xx_sent_ud_sm'  # Multilingual model for Tamil sentence segmentation
      TA_NER_MODEL = 'xx_ent_wiki_sm'      # Multilingual model for Tamil Named Entity Recognition
      ENG_MODEL = 'en_core_web_trf'        # Transformer-based model for English (Medical English)

      attr_reader :en_nlp, :ta_nlp_sents, :ta_nlp_ner

      class << self
        # Returns the singleton instance of Multilingual
        # @return [Multilingual] the singleton instance
        def instance
          @instance ||= new
        end
      end

      # Process English text for sentence segmentation and NER
      # @param text_or_texts [String, Array<String>] Text(s) to process
      # @param batch_size [Integer] Batch size for processing multiple texts
      # @return [Hash, Array<Hash>] Processed data with sentences and entities
      def process_english(text_or_texts, batch_size: 50)
        if text_or_texts.is_a?(Array)
          process_english_batch(text_or_texts, batch_size)
        else
          process_single_english_text(text_or_texts)
        end
      rescue StandardError => e
        handle_processing_error(e, 'English processing error')
      end

      # Process Tamil text for sentence segmentation and NER
      # @param text_or_texts [String, Array<String>] Text(s) to process
      # @param batch_size [Integer] Batch size for processing multiple texts
      # @return [Hash, Array<Hash>] Processed data with sentences and entities
      def process_tamil(text_or_texts, batch_size: 50)
        if text_or_texts.is_a?(Array)
          process_tamil_batch(text_or_texts, batch_size)
        else
          process_single_tamil_text(text_or_texts)
        end
      rescue StandardError => e
        handle_processing_error(e, 'Tamil processing error')
      end

      private

      # Initialize the models with optimized pipeline components
      # This is called only once due to the singleton pattern
      def initialize
        # Load English model with only necessary components for sentence segmentation and NER
        @en_nlp = Spacy::Language.new(
          ENG_MODEL
        )

        # Load Tamil sentence segmentation model with minimal components
        @ta_nlp_sents = Spacy::Language.new(
          TA_SENTENCE_MODEL
        )

        # Load Tamil NER model with minimal components
        @ta_nlp_ner = Spacy::Language.new(
          TA_NER_MODEL
        )
      end

      # Process a batch of English texts
      # @param texts [Array<String>] Array of texts to process
      # @param batch_size [Integer] Batch size for processing
      # @return [Array<Hash>] Array of processed data
      def process_english_batch(texts, batch_size)
        docs = @en_nlp.pipe(texts, batch_size: batch_size)
        docs.map { |doc| extract_english_data(doc) }
      end

      # Process a single English text
      # @param text [String] Text to process
      # @return [Hash] Processed data with sentences and entities
      def process_single_english_text(text)
        doc = @en_nlp.read(text)
        extract_english_data(doc)
      end

      # Extract structured data from an English doc
      # @param doc [Spacy::Doc] Processed document
      # @return [Hash] Structured data with sentences and entities
      def extract_english_data(doc)
        {
          sentences: doc.sents.map(&:text),
          entities: doc.ents.map { |ent| { text: ent.text, label: ent.label_ } }
        }
      end

      # Process a batch of Tamil texts
      # @param texts [Array<String>] Array of texts to process
      # @param batch_size [Integer] Batch size for processing
      # @return [Array<Hash>] Array of processed data
      def process_tamil_batch(texts, batch_size)
        # Process sentences
        sent_docs = @ta_nlp_sents.pipe(texts, batch_size: batch_size)

        # Process NER
        ner_docs = @ta_nlp_ner.pipe(texts, batch_size: batch_size)

        # Combine results
        sent_docs.zip(ner_docs).map do |sent_doc, ner_doc|
          {
            sentences: sent_doc.sents.map(&:text),
            entities: ner_doc.ents.map { |ent| { text: ent.text, label: ent.label_ } }
          }
        end
      end

      # Process a single Tamil text
      # @param text [String] Text to process
      # @return [Hash] Processed data with sentences and entities
      def process_single_tamil_text(text)
        sent_doc = @ta_nlp_sents.read(text)
        ner_doc = @ta_nlp_ner.read(text)

        {
          sentences: sent_doc.sents.map(&:text),
          entities: ner_doc.ents.map { |ent| { text: ent.text, label: ent.label_ } }
        }
      end

      # Handle processing errors
      # @param error [Exception] The error that occurred
      # @param context [String] Context information about where the error occurred
      # @return [Hash] Error information
      def handle_processing_error(error, context)
        error_info = {
          error: true,
          message: "#{context}: #{error.message}",
          sentences: [],
          entities: []
        }

        # Log the error for debugging
        puts "#{context}: #{error.message}\n#{error.backtrace.join("\n")}" if defined?(Rails) && Rails.logger

        error_info
      end
    end
  end
end
