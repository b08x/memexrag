# File: lib/memexrag/tools/informer_embedding_tool.rb
require 'ruby_llm'
require 'informers' # Make sure informers gem is loaded


module MemexRAG
  module Tools
    class InformerEmbedding < RubyLLM::Tool
      include Logging

      # Simple cache for pipeline instances
      # NOTE: Consider thread-safety if using in a multi-threaded environment (e.g., Puma, Sidekiq)
      # Using a Concurrent::Hash might be better in those cases.
      @@pipeline_cache = {}
      @@cache_mutex = Mutex.new

      description 'Generates embeddings for text using local models via the Informers gem.'

      # Parameters: text (or sentences), model_key
      param :text, desc: 'A single string or an array of strings to embed.'
      param :model_key, desc: 'The key for the embedding model to use (e.g., "all-MiniLM-L6-v2", "multi-qa").', default: 'multi-qa'
      # Add other potential Informers options as params if needed (e.g., dtype, device)
      # param :dtype, desc: 'Data type (e.g., "fp16")', optional: true
      # param :device, desc: 'Device (e.g., "cuda")', optional: true

      # Map friendly keys to actual model identifiers used by Informers
      # You might load this from a config file instead
      SUPPORTED_MODELS = {
        'all-MiniLM-L6-v2' => 'sentence-transformers/all-MiniLM-L6-v2',
        'multi-qa' => 'sentence-transformers/multi-qa-MiniLM-L6-cos-v1',
        'all-mpnet-base-v2' => 'sentence-transformers/all-mpnet-base-v2',
        'mxbai-embed-large' => 'mixedbread-ai/mxbai-embed-large-v1',
        'gte-small' => 'Supabase/gte-small'
        # Add other models from informers.md or your config as needed
      }.freeze

      def execute(text:, model_key: 'multi-qa')
        model_id = SUPPORTED_MODELS[model_key]
        unless model_id
          logger.error "Unsupported model key for InformerEmbeddingTool: #{model_key}"
          return { error: "Unsupported local embedding model key: #{model_key}. Supported: #{SUPPORTED_MODELS.keys.join(', ')}" }
        end

        begin
          # Get or create the Informers pipeline instance (with simple caching)
          pipeline = @@cache_mutex.synchronize do
            @@pipeline_cache[model_id] ||= begin
              logger.info "Loading Informers embedding pipeline: #{model_id}"
              # Pass other options like dtype, device if needed
              Informers.pipeline('embedding', model_id)
            end
          end

          # Call the pipeline
          # Informers pipeline seems to accept string or array directly
          logger.debug "Running Informers embedding for model: #{model_id}"
          embedding_result = pipeline.call(text)
          logger.info "Informers embedding successful for model: #{model_id}"

          # Return the result (might be a single vector or array of vectors)
          embedding_result
        rescue StandardError => e
          logger.error "InformerEmbeddingTool error (Model: #{model_id}): #{e.message}"
          logger.debug e.backtrace.join("\n")
          # Raising here as per tools.md convention for unexpected errors
          # Or return { error: ... } if it might be recoverable (e.g., model file issue)
          raise "Error during local embedding generation with #{model_id}: #{e.message}"
        end
      end
    end
  end
end

# --- How to use it ---
# require_relative 'memexrag/tools/informer_embedding_tool'
#
# informer_tool = MemexRAG::Tools::InformerEmbedding.new
#
# # Embed single sentence
# embedding1 = informer_tool.execute(text: "This is a test.", model_key: 'all-MiniLM-L6-v2')
# puts embedding1.inspect
#
# # Embed multiple sentences
# embeddings2 = informer_tool.execute(text: ["Sentence one.", "Sentence two."], model_key: 'multi-qa')
# puts embeddings2.inspect
