# lib/memexrag/parsers

File parsers for various formats.

## PARSERS

| Parser | File | Format |
|--------|------|--------|
| Base | `base.rb` | Abstract base class |
| Markdown | `markdown_ast.rb` | Markdown (via redcarpet) |
| MarkdownSectionSplitter | `markdown/section_splitter.rb` | Section-aware markdown |
| JSON | `json.rb` | JSON files |
| JSONL | `jsonl.rb` | JSON Lines |
| PlainText | `plaintext.rb` | Plain text |
| SRT | `srt.rb` | SubRip subtitles |
| WebVTT | `webvtt.rb` | WebVTT subtitles |

## PATTERNS

- Extend `MemexRAG::Parsers::Base`
- Implement `#parse(file_path)` method
- Return structured data hash

## ANTI-PATTERNS

- **Duplicate strategy**: `processors/loader.rb` also does parsing (Langchain-based) - potential inconsistency
- **No unified interface**: Different parsers return different structures
