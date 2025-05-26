# frozen_string_literal: true

# Ensure DB is connected and Sequel::Model.db is set, typically in database.rb
# module MemexRAG
#   module SequelModels # Optional namespace
class DocumentRecord < Sequel::Model(PGConnect.instance.db[:documents]) # Explicitly connect to the 'documents' table
  # However, being explicit with `Model(DB[:documents])` is safer if multiple DBs or complex setups exist.

  plugin :pgvector, :embedding # Register the 'embedding' column with the pgvector plugin

  # You might not need this if you only fetch data and don't save/update embeddings here
  # but good for completeness if you ever were to save.
  # PGVvector needs to know the dimensions if you were to *set* an embedding directly
  # through the model and have it validated/typecast.
  # For querying, it's less critical here but good practice if the model also writes.
  # self.vector_dimensions = 1024 # For 'BAAI/bge-large-en-v1.5'

  # No explicit table name definition needed if class name is DocumentRecord and table is document_records
  # or if class name is Document and table is documents.
  # If your table is `documents` and class is `DocumentRecord`, you can set it:
  set_dataset PGConnect.instance.db[:documents] unless table_name == :document_records

  # Example of how to use the nearest_neighbors method that the plugin provides:
  # def self.semantic_search(query_embedding, k: 5, distance_metric: "cosine")
  #   self.nearest_neighbors(
  #     :embedding,                       # The vector column name
  #     query_embedding,                   # The query vector (array of floats)
  #     distance: distance_metric          # "cosine", "euclidean" (L2), or "inner_product"
  #   ).limit(k)
  # end
end
