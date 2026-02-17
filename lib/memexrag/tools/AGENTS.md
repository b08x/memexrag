# lib/memexrag/tools

Executable tools for document processing, search, and translation.

## TOOLS

| Tool | File | Purpose |
|------|------|---------|
| SemanticSearch | `semantic_search.rb` | Hybrid vector + BM25F search |
| DoclingConverter | `docling_converter.rb` | Document conversion via external service |
| MarianTranslate | `marian_translate.rb` | Translation using MarianMT |
| SpacyNLP | `spacy_nlp.rb` | spaCy-based NLP processing |
| ImageConverter | `image_converter.rb` | Image format conversion |

## PATTERNS

- Each tool extends base functionality and provides `execute` method
- Tools are instantiated in `app.rb` routes (e.g., `docling_tool`)
- Return hash with `:status` key ('SUCCESS' or 'FAILURE')
- Error handling via begin/rescue blocks

## ANTI-PATTERNS

- **No error raising**: Tools return error hashes rather than raising exceptions
- **Model initialization in constructor**: Heavy model loading happens at initialization
