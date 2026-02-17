# lib/memexrag/models

Data models for PostgreSQL (via Sequel) and Redis (via Ohm).

## SEQUEL MODELS (PostgreSQL)

Located in `models/sequel/` - require `database.rb` connection.

| Model | File | Purpose |
|-------|------|---------|
| Collection | `collection.rb` | Document collections |
| Item | `item.rb` | Collection items |
| Document | `document.rb` | Document records |
| DocumentRecord | `document_record.rb` | Document metadata |
| Section | `section.rb` | Document sections with vectors |
| Image | `image.rb` | Image metadata |
| Audio | `audio.rb` | Audio metadata |
| Video | `video.rb` | Video metadata |

## OHM MODELS (Redis)

Located in `models/ohm/` - NLP metadata and caching.

| Model | File | Purpose |
|-------|------|---------|
| Page | `page.rb` | Page-level elements |
| Paragraph | `paragraph.rb` | Paragraphs |
| Sentence | `sentence.rb` | Sentences |
| Word | `word.rb` | Words |
| Phrase | `phrase.rb` | Phrases |
| Topic | `topic.rb` | Topic categorization |
| TextFile | `textfile.rb` | Text file cache |
| Section::* | `section/*.rb` | CodeBlock, Table, Image, Link |

## ANTI-PATTERNS

- **Chunk table missing**: `Chunk` model in `database.rb` is commented out - needed for pgvector
- **Redis connection**: Connection at load time, no retry mechanism
