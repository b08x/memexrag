# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-17
**Commit:** 4cfadec
**Branch:** development

## OVERVIEW

MemexRAG is a Ruby-based Retrieval-Augmented Generation (RAG) system with a Sinatra web interface. Integrates PostgreSQL (pgvector), Redis (Ohm), and multiple AI/LLM providers for document processing, semantic search, and translation.

## STRUCTURE

```
./
├── app.rb                    # Sinatra entry point
├── lib/memexrag/             # Main library
│   ├── clients/              # External API clients (Dify, Langfuse, Flowise)
│   ├── config/               # YAML configs + Config class
│   ├── models/               # Data models (sequel + ohm)
│   │   ├── sequel/           # PostgreSQL models
│   │   └── ohm/              # Redis models
│   ├── nlp/                  # NLP utilities (spaCy)
│   ├── parsers/              # File parsers (markdown, json, srt, vtt, etc.)
│   ├── processors/           # Document processors (Docling, Langchain)
│   ├── tools/                 # Executable tools (semantic_search, translator)
│   └── ui/                   # TUI components (TTY-based)
├── bin/                      # CLI utilities (gitlab, file_search)
├── views/                    # Slim templates
└── public/                   # Static assets (CSS, JS, uploads)
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add new file parser | `lib/memexrag/parsers/` | Extend `Base` class |
| Add new tool | `lib/memexrag/tools/` | Follow `SemanticSearch` pattern |
| Database model | `lib/memexrag/models/sequel/` | Sequel::Model subclass |
| Redis model | `lib/memexrag/models/ohm/` | Ohm::Model subclass |
| Web routes | `app.rb` | Sinatra handlers |
| Config | `lib/memexrag/config.rb` + `.env` | Environment-based |
| TUI | `lib/memexrag/ui/` | TTY toolkit components |

## CODE MAP

| Symbol | Type | Location | Notes |
|--------|------|----------|-------|
| MemexRAG | module | `lib/memexrag.rb` | Main namespace |
| App | class | `app.rb` | Sinatra application |
| Config | class | `lib/memexrag/config.rb` | Settings loader |
| Database | module | `lib/memexrag/database.rb` | Sequel connection |
| SemanticSearch | class | `lib/memexrag/tools/semantic_search.rb` | Hybrid search |
| DoclingConverter | class | `lib/memexrag/tools/docling_converter.rb` | Document conversion |

## CONVENTIONS

- **RuboCop**: Project uses RuboCop with custom config (see Gemfile)
- **Ruby version**: 3.x (check .ruby-version if exists)
- **Frozen string literal**: All files use `# frozen_string_literal: true`
- **Naming**: snake_case for files, CamelCase for classes
- **Dependencies**: Defined in Gemfile, installed via `bundle install`
- **Config**: YAML files in `lib/memexrag/config/`, loaded via `Config` class

## ANTI-PATTERNS (THIS PROJECT)

- **Chunk model missing**: The `Chunk` table in `database.rb` is commented out - needed for pgvector semantic search
- **Python integration**: Use `Open3` instead of backticks for robust error handling
- **File uploads**: Basic sanitization only - use Shrine for production
- **Temp files**: Manual cleanup required - no automatic cleanup in ensure blocks

## COMMANDS

```bash
# Run web server
ruby app.rb

# Run tests
rspec

# RuboCop
rubocop

# CLI tools
ruby bin/file_search.rb
ruby bin/gitlab_issues.rb
```

## NOTES

- Redis required on localhost:6379, db 15 for Jongleur worker tasks
- PostgreSQL with pgvector extension required for semantic search
- Python scripts use virtualenv - ensure activated before running
- Uploaded files go to `public/uploads/`
