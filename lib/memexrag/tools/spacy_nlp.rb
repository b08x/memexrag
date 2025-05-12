# frozen_string_literal: true

# Ensure Spacy module is available.
# If ruby-spacy is a gem, it might be `require 'ruby-spacy'`.
# If it's a local file, the application's load path should handle it.
# For this example, we assume `Spacy` module and its classes are accessible.

# The `SpacyNLP` class provides an interface to the spaCy NLP library
# for performing various natural language processing tasks. It is designed
# to be used as a tool within the RubyLLM framework.
#
# It allows for tasks such as Part-of-Speech (POS) tagging, dependency parsing,
# lemmatization, and named entity recognition on a given input text.
#
# @example Basic usage
#   nlp_tool = SpacyNLP.new
#   results = nlp_tool.execute(text: "Apple is looking at buying U.K. startup for $1 billion")
#   if results[:error]
#     puts "Error: #{results[:error]}"
#   else
#     results.each do |token|
#       puts "#{token[:surface]} - POS: #{token[:pos]}, Lemma: #{token[:lemma]}"
#     end
#   end
class SpacyNLP < RubyLLM::Tool
  # Define the spaCy model to be used by this tool.
  # Ensure this model (e.g., "en_core_web_trf") is installed in your Python environment
  # where ruby-spacy operates.
  # @return [String] The name of the spaCy model.
  SPACY_MODEL_NAME = 'en_core_web_trf'

  description "Performs Natural Language Processing tasks like Part-of-Speech (POS) tagging and dependency parsing on input text using the pre-configured '#{SPACY_MODEL_NAME}' spaCy model. Allows selection of specific tasks to perform."

  # @!method text
  #   @!scope class
  param :text,
        type: :string,
        desc: 'The input text to be analyzed.',
        required: true

  # Initializes the `SpacyNLP` tool.
  # It attempts to load the pre-configured spaCy language model.
  # If the model fails to load, an error message is stored, which will be
  # returned by the {#execute} method if called.
  #
  # @see SPACY_MODEL_NAME
  # @raise [PyCall::PyError, StandardError] Catches errors during model loading and stores an error message.
  def initialize
    super
    # Load the spaCy language model using the class constant
    @nlp = Spacy::Language.new(SPACY_MODEL_NAME)
  rescue PyCall::PyError, StandardError => e
    # Store the error to be returned by execute if initialization failed
    @initialization_error = { error: "Failed to load the pre-configured spaCy model '#{SPACY_MODEL_NAME}'. Ensure it is installed and valid. Details: #{e.message}" }
  end

  # Executes the NLP processing on the provided text.
  #
  # It first checks if the spaCy model was loaded successfully during initialization.
  # If not, it returns the stored initialization error.
  #
  # Then, it processes the input text using the loaded spaCy model and extracts
  # various linguistic features for each token, such as its surface form,
  # lemma, part-of-speech tag, dependency relation, named entity type,
  # and morphological features.
  #
  # @param text [String] The input text to be analyzed.
  # @return [Array<Hash>, Hash] An array of hashes, where each hash represents a
  #   processed token and its linguistic features.
  #   Returns a hash with an `:error` key if any error occurs during
  #   model loading (if not already caught in initialize) or during processing.
  #   The token hash includes:
  #   - `:surface` [String] The original token text.
  #   - `:lemma` [String] The base form of the token.
  #   - `:pos` [String] The simple part-of-speech tag.
  #   - `:tag` [String] The detailed part-of-speech tag.
  #   - `:dep` [String] The syntactic dependency relation.
  #   - `:ent_type` [String] The named entity type.
  #   - `:morphology` [String] Morphological features.
  #
  # @example Processing text
  #   tool = SpacyNLP.new
  #   result = tool.execute(text: "This is a test.")
  #   # result will be an array of token hashes or an error hash.
  #
  # @raise [StandardError] Catches unexpected errors during spaCy processing and returns an error hash.
  def execute(text:)
    return @initialization_error if @initialization_error
    return { error: 'spaCy model (@nlp) not initialized.' } unless @nlp

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
          morphology: token.morphology(hash: false) # Get morphology as a string
        }
      end
    rescue StandardError => e
      # Return a hash with an error key
      return { error: "An unexpected error occurred during spaCy processing: #{e.message}" }
    end

    # Return the array of processed token hashes directly, or wrap it if preferred
    # For now, returning the array as per the refactoring spirit.
    # If tools are expected to always return a hash, this could be { tokens: processed_tokens }
    processed_tokens
  end
end
