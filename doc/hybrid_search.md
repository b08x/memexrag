# Hybrid Search in MemexRAG

This document explains the hybrid search implementation in MemexRAG, which combines vector similarity search with BM25F scoring for improved search results.

## Overview

The hybrid search approach in MemexRAG uses a two-step process:

1. **Vector Search**: First, we use vector embeddings to find semantically similar documents based on the query.
2. **BM25F Re-ranking**: Then, we re-rank these documents using BM25F scoring, which considers term frequency, document length, and field weights.

This approach combines the strengths of both methods:
- Vector search is good at understanding semantic meaning and finding relevant documents even when they don't contain the exact query terms.
- BM25F is good at ranking documents based on keyword relevance and can help filter out false positives from vector search.

## Using Hybrid Search

The `SemanticSearch` tool now supports hybrid search with the following parameters:

```ruby
search_tool = MemexRAG::Tools::SemanticSearch.new
results_json = search_tool.execute(
  query: "Your search query here",
  k: 5,                           # Number of results to return
  distance_metric: 'cosine',      # Vector distance metric: "cosine", "euclidean", or "inner_product"
  use_hybrid_search: true,        # Whether to use hybrid search (default: true)
  vector_candidates: 10           # Number of vector search candidates to re-rank (default: 2*k)
)
```

### Parameters

- **query** (required): The search query to find relevant documents for.
- **k**: The number of top relevant documents to retrieve (default: 5).
- **distance_metric**: Distance metric for vector search: "cosine", "euclidean" (L2), or "inner_product" (default: "cosine").
- **use_hybrid_search**: Whether to use hybrid search (vector + BM25F). Set to `false` to use only vector search (default: true).
- **vector_candidates**: Number of candidates to retrieve from vector search for re-ranking. If not specified, defaults to `min(2*k, 20)`.

### Return Value

The tool returns a JSON string containing an array of documents, each with the following fields:

```json
[
  {
    "id": "document_id",
    "pageContent": "The content of the document...",
    "metadata": {
      "title": "Document Title",
      "source": "Document Source",
      ...
    }
  },
  ...
]
```

## How It Works

### Vector Search

Vector search uses the pgvector plugin for PostgreSQL to find the most similar documents based on vector embeddings. The process is:

1. The query is embedded using the BAAI/bge-large-en-v1.5 model.
2. The embedding is used to find the nearest neighbors in the vector space.
3. The top `vector_candidates` documents are retrieved.

### BM25F Re-ranking

BM25F re-ranking uses the BM25F algorithm to score documents based on term frequency, document length, and field weights. The process is:

1. The documents from vector search are preprocessed for BM25F.
2. The BM25F model is fitted to these documents with field weights (content: 1.0, title: 0.5).
3. The documents are scored using the query.
4. The documents are sorted by score and the top `k` are returned.

## Example Usage

```ruby
require 'memexrag'

# Initialize the search tool
search_tool = MemexRAG::Tools::SemanticSearch.new

# Basic hybrid search (default)
results_json = search_tool.execute(query: "What is semantic search?", k: 5)
results = JSON.parse(results_json)

# Vector search only (no BM25F re-ranking)
results_json = search_tool.execute(
  query: "What is vector similarity?",
  k: 5,
  use_hybrid_search: false
)
results = JSON.parse(results_json)

# Hybrid search with custom parameters
results_json = search_tool.execute(
  query: "How does BM25F scoring work?",
  k: 3,
  vector_candidates: 10,
  distance_metric: 'cosine'
)
results = JSON.parse(results_json)
```

See the `examples/hybrid_search_test.rb` file for a complete example.

## Performance Considerations

- Hybrid search is more computationally expensive than vector search alone, as it requires both vector similarity calculation and BM25F scoring.
- The `vector_candidates` parameter controls the trade-off between search quality and performance. A higher value may give better results but will be slower.
- For large document collections, consider optimizing the PostgreSQL database with appropriate indexes and configuration.

## References

- [BM25F: An Extension of BM25 for Multiple Fields](https://en.wikipedia.org/wiki/Okapi_BM25)
- [Vector Similarity Search: From Basics to Production](https://www.pinecone.io/learn/vector-similarity/)
- [pgvector: Open-source vector similarity search for Postgres](https://github.com/pgvector/pgvector)