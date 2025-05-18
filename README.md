# Memex-RAG: Associative Memory Trails for IT Diagnostic

## 🧠 Project Vision

**Memex-RAG** is a Ruby-based intelligent diagnostic system that combines Retrieval-Augmented Generation (RAG) with Vannevar Bush's visionary Memex concept to revolutionize IT support. By fusing semantic retrieval with associative memory trails, we create a system that understands hidden connections between incidents, mirroring human cognitive patterns.

> "Wholly new forms of encyclopedia will appear, ready made with a mesh of associative trails..."
> — *Vannevar Bush, "As We May Think"*

## 🎯 Business Value

For IT support teams, Memex-RAG will:

- **Reduce MTTR by 40%** through contextual incident linking
- **Boost first-contact resolution by 25%** with AI-powered diagnostics
- **Cut knowledge base search time by 50%** via associative trails

## 🔄 System Architecture

Memex-RAG combines Ruby components with modern ML infrastructure:

![Architecture diagram](./docs/assets/architecture.png) *[Draft available in /docs]*

### Core Components

#### Ruby Backend

- **MemexTrail System**: Graph-based connection between incidents (stored in RedisGraph)
- **Hybrid Retrieval**: Combines vector search (Redis) + graph traversal
- **Sublayer Task Generator**: New generator for creating Sublayer tasks (SublayerTaskGenerator)
- **Semantic Search**: Enhanced semantic search tool with BM25F integration
- **CustomFileLoader**: Advanced document processing with image and table extraction
- **Document Conversion**: Synchronous document processing pipeline
- **Langfuse Integration**: Comprehensive prompt management with versioning
- **Agent Framework**: LLM interaction management with RubyLLM

#### Interface Layer

- **CLI**: Incident investigation workflow via Thor
- **Web Interface**:
  - Radiology Translation & Media Analysis UI
  - Document processing interface
- **REST API**: Sinatra endpoints for backend services

## 🛣️ Development Roadmap (Q2 2025)

### Recent Updates

- Added Sublayer Task Generator for creating Sublayer tasks (SublayerTaskGenerator)
- Refactored SemanticSearch tool with BM25F integration
- Implemented CustomFileLoader for advanced document processing
- Added synchronous document conversion pipeline
- Updated document processing UI with improved structure display

### Phase 1: Foundation (Sprint 1-2)

- Implement CLI with Thor
- Redis vector search POC
- Sublayer task generator implementation
- Document processing pipeline

### Phase 2: Core Features (Sprint 3-4)

- NLP pipeline with ruby-spacy
- LLM diagnostic chain via ruby_llm
- API endpoints for document processing
- Semantic search improvements

### Phase 3: Optimization (Sprint 5-6)

- Performance benchmarking
- RBAC for API endpoints
- Automated testing suite

## 📊 Success Metrics

| Category          | Metric                          | Target  | Measurement Method               |
|-------------------|---------------------------------|---------|-----------------------------------|
| Technical         | API latency (p95)              | <500ms  | Prometheus monitoring            |
| Business          | MTTR reduction                 | 40%     | Jira incident analysis           |
| User Experience   | Document processing time       | <2s     | Performance monitoring           |

## 💡 Key Technical Innovations

### Sublayer Task Generation

- **Code Generation**: Creates Sublayer tasks from descriptions
- **Example-based**: Uses example tasks for generation
- **Extensible**: Supports custom task types

### Enhanced Semantic Search

- **BM25F Integration**: Combines BM25F with vector search
- **Hybrid Search**: Supports both semantic and keyword search
- **Distance Metrics**: Supports cosine and other distance metrics

### Document Processing

- **CustomFileLoader**: Advanced document loading with:
  - Image extraction
  - Table extraction
  - Chunking
- **Synchronous Processing**: Immediate document conversion
- **Structure Display**: Visual document structure visualization

## 👥 Stakeholders

| Role               | Responsibility                          |
|--------------------|-----------------------------------------|
| Developers         | System implementation and maintenance  |
| Data Scientists    | Model training and optimization         |
| IT Support Staff   | System usage and feedback               |

## 🛠️ Technology Stack

| Component         | Choice                      |
|-------------------|-----------------------------|
| NLP               | ruby-spacy                  |
| Search            | Redis + BM25F               |
| Document Process  | CustomFileLoader            |
| Web Framework     | Sinatra                     |

## 📚 Resources

- [API Spec](https://github.com/yourorg/memex-rag/blob/main/docs/api-spec.md)
- [Contribution Guide](./CONTRIBUTING.md)
- [Roadmap Details](./docs/roadmap.md)

## ⚠️ Risk Mitigation

1. **Search Performance**:
   - Hybrid search optimization
   - Indexing strategy refinement

2. **Document Processing**:
   - Chunking strategy optimization
   - Memory management

---

**Project Status**: Active Development (Sprint 2)  
**Recent Updates**:  

- Added Sublayer Task Generator  
- Refactored Semantic Search  
- Implemented CustomFileLoader  
- Document processing improvements  

**Next Release**: 2025-06-30  
**Lead Maintainer**: [Your Name]
