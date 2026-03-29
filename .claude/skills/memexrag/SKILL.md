```markdown
# memexrag Development Patterns

> Auto-generated skill from repository analysis

## Overview

This skill teaches you how to contribute to the `memexrag` Ruby codebase, which is focused on agent orchestration, file parsing, database modeling, and CLI tooling for information retrieval and processing. You'll learn the project's coding conventions, how to implement common workflows, and how to use suggested commands for efficient collaboration.

## Coding Conventions

- **File Naming:**  
  Use `snake_case` for all file and directory names.  
  _Example:_  
  ```
  lib/memexrag/agents/multi_agent_workflow_gen.rb
  ```

- **Import Style:**  
  Use relative imports within the `lib/memexrag` namespace.  
  _Example:_  
  ```ruby
  require_relative '../models/document'
  ```

- **Export Style:**  
  Use named exports (explicitly define classes or modules to be used elsewhere).  
  _Example:_  
  ```ruby
  # lib/memexrag/agents/agent.rb
  module Memexrag
    module Agents
      class Agent
        # ...
      end
    end
  end
  ```

- **Commit Patterns:**  
  - Use prefixes like `feat:` for features and `chore:` for maintenance.
  - Keep commit messages concise (average ~54 characters).

## Workflows

### Add or Update Agent Orchestration
**Trigger:** When introducing or updating agent orchestration, Langfuse integration, or multi-agent workflow generation  
**Command:** `/add-agent-orchestration`

1. Edit or add files in `lib/memexrag/agents/` (e.g., `agent.rb`, `orch.rb`, `multi-agent-workflow-gen.rb`).
2. Edit or add files in `lib/memexrag/clients/` (e.g., `langfuse_client.rb`, `dify_client.rb`).
3. Optionally update `lib/memexrag/commands/` (e.g., `promptlist.rb`, `ingest.rb`).
4. Optionally update `lib/memexrag/processors/multilingual.rb` or related processor files.
5. Update or add documentation or markdown files if needed.

_Example:_
```ruby
# lib/memexrag/agents/orch.rb
module Memexrag
  module Agents
    class Orch
      def orchestrate
        # orchestration logic
      end
    end
  end
end
```

---

### Add or Refactor Database Models and Schema
**Trigger:** When adding new data types, migrating models, or refactoring database structure  
**Command:** `/add-model`

1. Edit or add files in `lib/memexrag/models/` (e.g., `sequel/*.rb`, `ohm/*.rb`, `document.rb`, `fileobject.rb`).
2. Edit `lib/memexrag/database.rb` to update schema or connection logic.
3. Optionally update `Gemfile` if new gems are needed.
4. Update or remove related tools or commands if model structure changes.

_Example:_
```ruby
# lib/memexrag/models/document.rb
module Memexrag
  module Models
    class Document < Sequel::Model
      # model definition
    end
  end
end
```

---

### Add or Enhance File Parsers and Processors
**Trigger:** When supporting a new file type, improving chunking, or adding new processing capabilities  
**Command:** `/add-parser`

1. Add or edit files in `lib/memexrag/parsers/` (e.g., `markdown.rb`, `markdown/section_splitter.rb`, `json.rb`).
2. Add or edit files in `lib/memexrag/processors/` (e.g., `ruby-docling.rb`, `multilingual.rb`, `loader.rb`).
3. Optionally update `lib/memexrag/parser.rb` to register new parsers.
4. Update or add test or documentation files if needed.

_Example:_
```ruby
# lib/memexrag/parsers/markdown.rb
module Memexrag
  module Parsers
    class Markdown
      def parse(file)
        # parsing logic
      end
    end
  end
end
```

---

### Add or Update CLI Commands and Tools
**Trigger:** When adding a new CLI command, tool, or enhancing the CLI interface  
**Command:** `/add-cli-command`

1. Add or edit files in `lib/memexrag/commands/` (e.g., `converse.rb`, `ingest.rb`, `add.rb`).
2. Add or edit files in `lib/memexrag/tools/` (e.g., `semantic_search.rb`, `spacy_nlp.rb`, `docling_converter.rb`, `marian_translate.rb`).
3. Edit `lib/memexrag/cli.rb` or `lib/memexrag/command.rb` to register new commands.
4. Optionally update `bin/` scripts if new CLI entrypoints are needed.

_Example:_
```ruby
# lib/memexrag/commands/converse.rb
module Memexrag
  module Commands
    class Converse
      def execute(args)
        # CLI logic
      end
    end
  end
end
```

---

### Documentation and README Updates
**Trigger:** When documenting new features, updating project vision, or adding usage guides  
**Command:** `/update-docs`

1. Edit `README.md` or other top-level markdown files.
2. Add or update files in `doc/` or `AGENTS.md`.
3. Optionally update inline documentation in code files.

_Example:_
```markdown
# AGENTS.md

## Orchestration Agents
- Description and usage examples...
```

## Testing Patterns

- **Framework:** Unknown (no explicit framework detected).
- **File Pattern:** Test files use the `*.test.*` naming convention.
- **Location:** Tests are typically located alongside the code or in dedicated test directories.
- **Example:**
  ```
  lib/memexrag/agents/agent.test.rb
  ```

## Commands

| Command                 | Purpose                                                      |
|-------------------------|--------------------------------------------------------------|
| /add-agent-orchestration| Add or update agent orchestration logic                      |
| /add-model              | Add or refactor database models and schema                   |
| /add-parser             | Add or enhance file parsers and processors                   |
| /add-cli-command        | Add or update CLI commands and tools                         |
| /update-docs            | Update documentation, README, or markdown guides             |
```
