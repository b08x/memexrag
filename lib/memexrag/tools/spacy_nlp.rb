# frozen_string_literal: true

class SpacyNLP < RubyLLM::Tool
  SPACY_MODEL_NAME = 'en_core_web_trf'

  description "Performs Natural Language Processing tasks... using the pre-configured '#{SPACY_MODEL_NAME}' spaCy model..."

  param :text,
        type: :string,
        desc: 'The input text to be analyzed.',
        required: true

  def initialize
    super
    begin
      # Use the registry to get the model
      @nlp = SpacyModelRegistry.get_model(SPACY_MODEL_NAME)
    rescue StandardError => e
      # The registry now handles the direct loading error, so this catch
      # is for errors from the registry itself (e.g., if get_model raised).
      @initialization_error = { error: "Failed to obtain spaCy model '#{SPACY_MODEL_NAME}' from registry. Details: #{e.message}" }
    end
  end

  def execute(text:)
    return @initialization_error if @initialization_error
    # This check is a safeguard, but @initialization_error should be set if @nlp is nil due to registry failure.
    return { error: 'spaCy model (@nlp) was not initialized. Check logs for registry errors.' } unless @nlp

    processed_tokens = []
    begin
      doc = @nlp.read(text)
      processed_tokens = doc.tokens.map do |token|
        {
          surface: token.text,
          lemma: token.lemma_,
          pos: token.pos_,
          tag: token.tag_,
          dep: token.dep_,
          ent_type: token.ent_type_,
          morphology: token.morphology(hash: false)
        }
      end
    rescue StandardError => e
      return { error: "An unexpected error occurred during spaCy processing: #{e.message}" }
    end
    processed_tokens
  end
end
