# lib/memexrag/tools/semantic_search.rb
require 'sequel'
require 'pgvector'
require 'informers' # For BAAI/bge-large-en-v1.5

# Assuming PGConnect is defined as in your database.rb
# and provides access to the Sequel DB instance.
# require_relative '../database' # Adjust path as needed

class SemanticSearch < RubyLLM::Tool
  include Logging
  # Parameters and description remain the same
  param :query, type: :string, desc: 'The search query to find relevant documents for.', required: true
  param :k, type: :integer, desc: 'The number of top relevant documents to retrieve.'
  param :distance_metric,
        type: :string,
        desc: 'Distance metric: "cosine", "euclidean" (L2), or "inner_product". Default: "cosine".'

  description <<~DESC
    Performs semantic search over a collection of documents using vector similarity.
    Given a query, it returns the top k most semantically similar documents
    from the memexrag database. Useful for finding information based on meaning
    rather than exact keywords.
  DESC

  # Embedding model configuration
  MODEL_NAME = 'BAAI/bge-large-en-v1.5'
  # BAAI models sometimes suggest adding instructions for retrieval queries.
  # For general purpose search, this can be an empty string or a generic instruction.
  # "Represent this sentence for searching relevant passages: "
  QUERY_INSTRUCTION = '' # Or "Represent this query for retrieving relevant documents: "

  def initialize
    super
    # Load the embedding model once upon initialization
    begin
      @embedding_model = Informers.pipeline('embedding', MODEL_NAME)
      # Informers might download the model on first run, which can take time.
      # Consider pre-downloading or providing feedback if it's a long init.
      logger.info "[SemanticSearch] Initialized embedding model: #{MODEL_NAME}"
    rescue StandardError => e
      logger.error "[SemanticSearch] Failed to initialize embedding model #{MODEL_NAME}: #{e.message}"
      # This is a critical failure; the tool won't work.
      # Depending on application structure, this might raise, or set a faulty state.
      @embedding_model = nil
    end

    # DB connection is handled by the DocumentRecord model via PGConnect
    # We just need to ensure the model is correctly set up.
    # If DocumentRecord.db is not set, this would fail later.
    # This check is more about the application's overall DB setup.
    unless PGConnect.instance&.db && DocumentRecord.db
      logger.fatal '[SemanticSearch] Database connection for DocumentRecord model not available.'
      # This indicates a setup issue.
    end

    logger.fatal '[SemanticSearch] Database connection for DocumentRecord model not available.'
    # This indicates a setup issue.
  end

  def execute(query:, k: 5, distance_metric: 'cosine')
    return { error: 'Embedding model not initialized.' }.to_json unless @embedding_model
    return { error: 'Database for DocumentRecord not configured.' }.to_json unless DocumentRecord.db

    logger.info "[SemanticSearch] Executing search: \"#{query}\", k: #{k}, distance: #{distance_metric}"

    begin
      query_to_embed = QUERY_INSTRUCTION.empty? ? query : "#{QUERY_INSTRUCTION}#{query}"
      query_embedding_array = @embedding_model.call([query_to_embed])
      query_embedding = query_embedding_array.first # This is an array of floats

      # Use the pgvector plugin's #nearest_neighbors method
      # The distance metric should match the index opclass for best performance
      # Your index uses `vector_cosine_ops`, so `distance: "cosine"` is appropriate.
      # Other options: "euclidean" for L2, "inner_product".

      # Ensure distance_metric is one of the supported values by the plugin
      valid_distances = %w[cosine euclidean inner_product] # Add "taxicab", "hamming", "jaccard" if applicable
      actual_distance_metric = valid_distances.include?(distance_metric.downcase) ? distance_metric.downcase : 'cosine'
      logger.warn "[SemanticSearch] Invalid distance_metric '#{distance_metric}', defaulting to 'cosine'." if actual_distance_metric != distance_metric.downcase

      # Accessing via the model class directly
      results = DocumentRecord
                .nearest_neighbors(
                  :embedding, # The vector column symbol
                  query_embedding, # The query vector (Array of Floats)
                  distance: actual_distance_metric
                )
                .limit(k)
                .select(:id, :pageContent, :metadata) # Select specific columns
                .all # Execute and get results

      logger.info "[SemanticSearch] Found #{results.count} documents."

      formatted_results = results.map do |doc|
        {
          id: doc.id, # Access attributes directly from model instances
          pageContent: doc.pageContent,
          metadata: if doc.metadata
                      doc.metadata.is_a?(String) ? JSON.parse(doc.metadata) : doc.metadata
                    else
                      {}
                    end
          # score: doc.neighbor_distance # The plugin adds this column
        }
      end

      formatted_results.to_json
    rescue Informers::Error => e
      logger.error "[SemanticSearch] Informers gem error: #{e.message}"
      { error: "Embedding generation failed: #{e.message}" }.to_json
    rescue Sequel::DatabaseError => e
      logger.error "[SemanticSearch] Database error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      { error: "Database query failed: #{e.message}" }.to_json
    rescue StandardError => e
      logger.error "[SemanticSearch] An unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      { error: "An unexpected error occurred: #{e.message}" }.to_json
    end
  end

  # def logger
  #   # Assuming a logger is available, e.g., from `include Logging`
  #   # If not, use Rails.logger or a new Logger.new(STDOUT)
  #   @logger ||= Logging.logger_for(self.class.name, __method__)
  # end
end

# Example Usage (outside of Rails/LLM context, for direct testing):
#
# Ensure your database is set up and you have some documents.
#
# require_relative 'path/to/your/pg_connect' # if separate
# require_relative 'semantic_search'
#
# # Mock PGConnect if not fully integrated for testing
# module MemexRAG
#   module PGConnect
#     def self.instance
#       OpenStruct.new(db: Sequel.connect(ENV.fetch('POSTGRES_URI'))) # Replace with your actual DB connection string
#     end
#   end
# end
#
# search_tool = MemexRAG::Tools::SemanticSearch.new
# results_json = search_tool.execute(query: "What is semantic search?", k: 3)
# puts JSON.pretty_generate(JSON.parse(results_json))
