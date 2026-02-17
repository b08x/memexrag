# MemexRAG

Ruby-based Retrieval-Augmented Generation system with Sinatra web interface. Integrates PostgreSQL (pgvector), Redis (Ohm), and multiple AI/LLM providers for document processing, semantic search, and translation.

## Components

- **Web**: Sinatra app (`app.rb`) — file upload, document conversion, translation proxy
- **Database**: Sequel models with pgvector for semantic search
- **Models**: Ohm (Redis) for NLP metadata; Sequel (PostgreSQL) for documents
- **Tools**: SemanticSearch, DoclingConverter, MarianTranslate, SpacyNLP
- **Clients**: Dify, Langfuse, Flowise
- **Parsers**: Markdown, JSON, JSONL, SRT, VTT, PlainText

## Known Issues

- **Chunk table commented out** — core semantic search requires this table in `database.rb`
- **Python scripts use backticks** — should use Open3 for robust error handling
- **File upload sanitization minimal** — basic filename gsub only, needs Shrine for production
- **Temp file cleanup incomplete** — orphaned files possible in DoclingConverter

## Run

```bash
ruby app.rb
rspec
```