# frozen_string_literal: true

# Ensure DB is connected and Sequel::Model.db is set, typically in database.rb
# module MemexRAG
#   module SequelModels # Optional namespace
class Section < Sequel::Model
  plugin :validation_helpers
  plugin :insert_conflict
  plugin :pgvector, :embedding # Register the 'embedding' column with the pgvector plugin

  many_to_one :document

  # Example of how to use the nearest_neighbors method that the plugin provides:
  # def self.semantic_search(query_embedding, k: 5, distance_metric: "cosine")
  #   self.nearest_neighbors(
  #     :embedding,                       # The vector column name
  #     query_embedding,                   # The query vector (array of floats)
  #     distance: distance_metric          # "cosine", "euclidean" (L2), or "inner_product"
  #   ).limit(k)
  # end
end
