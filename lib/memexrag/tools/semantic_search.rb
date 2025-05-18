# lib/memexrag/tools/semantic_search.rb
require 'sequel'
require 'pgvector'
require 'informers' # For BAAI/bge-large-en-v1.5
require 'bm25f'
require 'pragmatic_tokenizer'
require 'uea-stemmer'

# Assuming PGConnect is defined as in your database.rb
# and provides access to the Sequel DB instance.
# require_relative '../database' # Adjust path as needed
module MemexRAG
  module Tools
    class SemanticSearch < RubyLLM::Tool
      include Logging
      # Parameters
      param :query, type: :string, desc: 'The search query to find relevant documents for.', required: true
      param :k, type: :integer, desc: 'The number of top relevant documents to retrieve.'
      param :distance_metric,
            type: :string,
            desc: 'Distance metric: "cosine", "euclidean" (L2), or "inner_product". Default: "cosine".'
      param :use_hybrid_search,
            type: :boolean,
            desc: 'Whether to use hybrid search (vector + BM25F). Default: true.'
      param :vector_candidates,
            type: :integer,
            desc: 'Number of candidates to retrieve from vector search for re-ranking. Default: 2*k.'

      description <<~DESC
        Performs semantic search over a collection of documents using a hybrid approach.
        First uses vector similarity to retrieve initial candidates, then re-ranks them
        using BM25F scoring. Given a query, it returns the top k most relevant documents
        from the memexrag database. Useful for finding information based on both semantic
        meaning and keyword relevance.
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

        # Initialize BM25F model
        begin
          @bm25f_model = BM25F.new
          logger.info '[SemanticSearch] Initialized BM25F model'
        rescue StandardError => e
          logger.error "[SemanticSearch] Failed to initialize BM25F model: #{e.message}"
          @bm25f_model = nil
        end

        # DB connection is handled by the Chunk model via PGConnect
        # We just need to ensure the model is correctly set up.
        # If Chunk.db is not set, this would fail later.
        # This check is more about the application's overall DB setup.
        return if PGConnect.instance&.db && Chunk.db

        logger.fatal '[SemanticSearch] Database connection for Chunk model not available.'
        # This indicates a setup issue.
      end

      def execute(query:, k: 5, distance_metric: 'cosine', use_hybrid_search: true, vector_candidates: nil)
        return { error: 'Embedding model not initialized.' }.to_json unless @embedding_model
        return { error: 'Database for Chunk not configured.' }.to_json unless Chunk.db
        return { error: 'BM25F model not initialized.' }.to_json if use_hybrid_search && !@bm25f_model

        logger.info "[SemanticSearch] Executing search: \"#{query}\", k: #{k}, distance: #{distance_metric}, hybrid: #{use_hybrid_search}"

        begin
          # Determine number of vector candidates
          actual_vector_candidates = vector_candidates || (use_hybrid_search ? [k * 2, 20].min : k)

          # Perform vector search
          vector_results = vector_search(query, actual_vector_candidates, distance_metric)

          # If hybrid search is disabled or BM25F model is not available, return vector results
          unless use_hybrid_search && @bm25f_model
            formatted_results = format_results(vector_results)
            return formatted_results.to_json
          end

          # Re-rank vector results using BM25F
          reranked_results = rerank_with_bm25f(query, vector_results)

          # Limit to top k results
          final_results = reranked_results.first(k)

          # Format results
          formatted_results = format_results(final_results)

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

      # Vector search method
      def vector_search(query, k, distance_metric)
        query_to_embed = QUERY_INSTRUCTION.empty? ? query : "#{QUERY_INSTRUCTION}#{query}"
        query_embedding_array = @embedding_model.call([query_to_embed])
        query_embedding = query_embedding_array.first # This is an array of floats

        # Ensure distance_metric is one of the supported values by the plugin
        valid_distances = %w[cosine euclidean inner_product] # Add "taxicab", "hamming", "jaccard" if applicable
        actual_distance_metric = valid_distances.include?(distance_metric.downcase) ? distance_metric.downcase : 'cosine'
        logger.warn "[SemanticSearch] Invalid distance_metric '#{distance_metric}', defaulting to 'cosine'." if actual_distance_metric != distance_metric.downcase

        # Accessing via the model class directly
        results = Chunk
                  .nearest_neighbors(
                    :embedding, # The vector column symbol
                    query_embedding, # The query vector (Array of Floats)
                    distance: actual_distance_metric
                  )
                  .limit(k)
                  .select(:id, :pageContent, :metadata) # Select specific columns
                  .all # Execute and get results

        logger.info "[SemanticSearch] Vector search found #{results.count} documents."

        results
      end

      # BM25F preprocessing method
      def preprocess_for_bm25f(documents)
        documents.map do |doc|
          {
            id: doc.id,
            content: doc.pageContent,
            metadata: doc.metadata
          }
        end
      end

      # BM25F re-ranking method
      def rerank_with_bm25f(query, vector_results)
        return [] if vector_results.empty?

        # Preprocess documents for BM25F
        documents = preprocess_for_bm25f(vector_results)

        # Prepare documents for BM25F
        bm25f_docs = []
        documents.each_with_index do |doc, _idx|
          metadata = if doc[:metadata].is_a?(String)
                       begin
                         JSON.parse(doc[:metadata])
                       rescue JSON::ParserError
                         {}
                       end
                     else
                       doc[:metadata] || {}
                     end

          # Extract title from metadata or use a default
          title = metadata['title'] || metadata[:title] || ''

          bm25f_docs << {
            content: doc[:content] || '',
            title: title,
            id: doc[:id]
          }
        end

        # Fit BM25F model
        @bm25f_model.fit(bm25f_docs, { content: 1.0, title: 0.5 })

        # Score documents
        scores = @bm25f_model.score(query)

        # Sort documents by score
        ranked_docs = []
        scores.each do |idx, score|
          next if score.nil? || score.zero? # Skip documents with zero score

          ranked_docs << [vector_results[idx], score]
        end

        ranked_docs.sort_by! { |_, score| -score }
        ranked_results = ranked_docs.map { |doc, _| doc }

        logger.info "[SemanticSearch] BM25F re-ranking complete. Ranked #{ranked_results.size} documents."

        ranked_results
      end

      # Format results method
      def format_results(results)
        results.map do |doc|
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
      end

      # def logger
      #   # Assuming a logger is available, e.g., from `include Logging`
      #   # If not, use Rails.logger or a new Logger.new(STDOUT)
      #   @logger ||= Logging.logger_for(self.class.name, __method__)
      # end
    end
  end
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
