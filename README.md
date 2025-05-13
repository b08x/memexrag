# Memex-RAG: Associative Memory Trails for IT Diagnostics

## 🧠 Project Vision

**Memex-RAG** is a Ruby-based intelligent diagnostic system that combines Retrieval-Augmented Generation (RAG) with Vannevar Bush's visionary Memex concept to revolutionize IT support. By fusing semantic retrieval with associative memory trails, we create a system that understands hidden connections between incidents, mirroring human cognitive patterns.

> "Wholly new forms of encyclopedias will appear, ready made with a mesh of associative trails..."
> — *Vannevar Bush, "As We May Think"*

## 🎯 Business Value

For IT support teams, Memex-RAG will:

- **Reduce MTTR by 40%** through contextual incident linking
- **Boost first-contact resolution by 25%** with AI-powered diagnostics
- **Cut knowledge base search time by 50%** via associative trails

## 🔄 System Architecture

Memex-RAG combines Ruby components with modern ML infrastructure:

![Architecture Diagram](./docs/assets/architecture.png) *[Draft available in /docs]*

### Core Components

#### Ruby Backend

- **MemexTrail System**: Graph-based connections between incidents (stored in RedisGraph)
- **Hybrid Retrieval**: Combines vector search (Redis) + graph traversal
- **Advanced Langfuse Integration**: Comprehensive prompt management via Langfuse, including version-controlled prompts (fetched by name, version, or label), a PyCall bridge, and observability features for enhanced AI decision transparency.
- **Agent Framework**: Flexible LLM interaction via RubyLLM, enhanced by **direct Langfuse prompt integration** for dynamic and managed prompt usage, and supporting extensible capabilities through its tool framework.
- **Multi-Agent Workflow Generation**: Leverages [`lib/memexrag/agents/multi-agent-workflow-gen.rb`](lib/memexrag/agents/multi-agent-workflow-gen.rb) to orchestrate complex tasks across multiple specialized AI agents.
- **Dify Client Integration**: Includes [`lib/memexrag/clients/dify_client.rb`](lib/memexrag/clients/dify_client.rb) for seamless communication with the Dify AI application development platform.
- **ArchiveBox Retriever**: Integrates with ArchiveBox instances via [`lib/memexrag/retrievers/archivebox.rb`](lib/memexrag/retrievers/archivebox.rb) to fetch, manage, and utilize archived web content, snapshots, and associated metadata.
- **File Ingestion & Processing Pipeline**: Employs Jongleur workers for robust background task processing, including:
  - `ReadFileTask` ([`lib/memexrag/tasks/read_file.rb`](lib/memexrag/tasks/read_file.rb)): For asynchronous file reading.
  - `SegmentText` Task ([`lib/memexrag/tasks/segment.rb`](lib/memexrag/tasks/segment.rb)): For breaking down text into manageable segments.
  - `Multilingual` Processor ([`lib/memexrag/processors/multilingual.rb`](lib/memexrag/processors/multilingual.rb)): Utilizes Spacy for advanced NLP tasks in English and Tamil, with support for custom domain-specific terminology (e.g., radiology).
- **Document Storage**: PostgreSQL with vector embeddings for semantic search

#### Interface Layer

- **CLI**: Incident investigation workflows via Thor
- **Web Interfaces**:
  - **Radiology Translation & Media Analysis UI** ([`views/radiology_translate.slim`](views/radiology_translate.slim)): A cornerstone of the application, this advanced interface is specifically designed for translating radiology-related content. It supports image and video uploads, with frontend capabilities for **OCR, UI element identification, and translation of extracted/identified content** ([`public/js/script.js`](public/js/script.js)). This provides a rich, interactive experience for specialized medical localization tasks.
  - **General Translation UI** ([`views/translate.slim`](views/translate.slim)): A user-friendly interface for English-to-Tamil and other language pair translations, supporting text, file, and URL inputs, with progress indicators and comparative results display.
- **REST API**: Sinatra endpoints ([`app.rb`](app.rb)) providing backend support for the web interfaces and general integration, featuring:
  - `/upload`: For file uploads.
  - `/radiology/translate`: Serves the specialized radiology translation interface.
  - `/memexrag/proxy/translate`: Handles text translation requests, acting as a proxy to backend NLP workflows.

## 🛣️ Development Roadmap (Q3 2024)

### Phase 1: Foundation (Sprint 1-2)

- Implement CLI with `thor` for:
  - Incident ingestion (`memex ingest <file>`)
  - Basic trail visualization (`memex trace <incident_id>`)
- Redis vector search POC
- Langfuse prompt registry setup

### Phase 2: Core Features (Sprint 3-4)

- NLP pipeline with ruby-spacy (entity extraction)
- LLM diagnostic chains via ruby_llm
- API endpoints for:
  - `/incidents/search` (semantic + graph)
  - `/trails` (trail management)

### Phase 3: Optimization (Sprint 5-6)

- Performance benchmarking
- RBAC for API endpoints
- Automated testing suite (RSpec + Cypress)

## 📊 Success Metrics

| Category          | Metric                          | Target  | Measurement Method               |
|-------------------|---------------------------------|---------|-----------------------------------|
| Technical         | API latency (p95)              | <500ms  | Prometheus monitoring            |
| Business          | MTTR reduction                 | 40%     | Jira incident analysis           |
| User Experience   | CLI adoption rate              | >75%    | Usage telemetry                  |

## 💡 Key Technical Innovations

### Associative Trail Intelligence

- **Contextual Linking**: Auto-creates trails based on:
  - Shared root causes
  - Temporal patterns
  - Component dependencies
- **Expert Validation**: L3 technicians can curate/override trails

### Langfuse Integration

**Sophisticated Langfuse-Powered Prompt Engineering**:

- **Dynamic In-Agent Prompt Retrieval**: Agents can fetch specific prompt versions directly from Langfuse by name, version, or label, enabling agile updates and experimentation.
- **Centralized Prompt Management**: Provides a single source of truth for all prompts, enhancing consistency and maintainability.
- **Support for A/B Testing**: Facilitates the comparison of different prompt strategies to optimize AI performance.
- **Comprehensive Audit Trails**: Logs AI decisions and prompt usage for improved transparency and debugging.
- **Enhanced Observability**: Offers detailed insights into LLM interactions and prompt performance.

### Specialized UI for Advanced Media Analysis & Translation

- **Radiology-Focused Workflow**: The **Radiology Translation & Media Analysis UI** ([`views/radiology_translate.slim`](views/radiology_translate.slim)) provides a tailored solution for complex medical imaging and text scenarios.
- **Interactive Media Processing**: Users can upload images/videos and leverage client-side tools ([`public/js/script.js`](public/js/script.js)) for OCR, identification of UI elements within screenshots, and subsequent translation of this extracted information. This significantly aids in understanding and localizing visual medical data.
- **Multilingual NLP Backend**: Supported by a robust multilingual processing pipeline ([`lib/memexrag/processors/multilingual.rb`](lib/memexrag/processors/multilingual.rb)) using Spacy, initially for English and Tamil, with capabilities for custom domain-specific terminologies.

### Tool-Augmented Agents

- **Modular Tool Framework**: Agents can leverage specialized tools for enhanced capabilities
- **Runtime Tool Discovery**: Dynamic tool registration and invocation
- **Event-Driven Architecture**: Comprehensive event handlers for tool execution lifecycle
- **Extensible Design**: Custom tools can be easily created and integrated

## 👥 Stakeholders

| Role               | Responsibilities                          |
|--------------------|-------------------------------------------|
| L1 Technicians     | Daily system users, feedback providers    |
| L3 Specialists     | Trail validation, knowledge base curation |
| DevOps             | Infrastructure scaling, monitoring        |

## 🛠️ Technology Stack

| Component         | Choice                      | Rationale                             |
|-------------------|-----------------------------|---------------------------------------|
| NLP               | ruby-spacy                  | Python interoperability via PyCall    |
| Vector DB         | Redis + PostgreSQL          | Low-latency, embedding storage        |
| Orchestration     | Jongleur                    | Ruby-native DAG support               |
| LLM Framework     | RubyLLM, **`langchainrb`**  | Tool-augmented agent capabilities, expanded LLM interaction patterns |
| Web Framework     | Sinatra + Puma, **Slim (templating)** | Lightweight API endpoints and dynamic view rendering |

## 📚 Resources

- [API Spec](https://github.com/yourorg/memex-rag/blob/main/docs/api-spec.md) (Live Swagger)
- [Contribution Guide](./CONTRIBUTING.md) (Includes testing standards)
- [Roadmap Details](./docs/roadmap.md) (Quarterly milestones)

## ⚠️ Risk Mitigation

1. **LLM Hallucinations**:
   - Implement confidence scoring
   - Human-in-the-loop validation

2. **Performance Scaling**:
   - Redis cluster sharding plan
   - Async processing with Sidekiq

---

**Project Status**: Active Development (Sprint 2)
**Recent Enhancements**: Launched a Sinatra web application highlighted by an advanced Radiology Translation & Media Analysis UI (featuring OCR & UI identification). Significantly enhanced Agent capabilities with deep Langfuse integration for dynamic prompt management by name, version, or label. Introduced multi-agent workflow generation, ArchiveBox retriever, and Dify client. Implemented multilingual NLP processing (English/Tamil) with Spacy.
**Next Release**: 2024-06-30 (Phase 1 Feature Complete)
**Lead Maintainer**: [Your Name] | [Contact Info]
