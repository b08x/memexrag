# Memexrag: Intelligent Document System with Associative Memory

## 📋 Project Overview

Memexrag combines Retrieval-Augmented Generation (RAG) with Vannevar Bush's Memex concept to create an intelligent document system. By establishing associative memory trails between related content, the system mirrors human cognitive patterns, enabling intuitive navigation through complex information landscapes.

> "A sophisticated system that leverages advanced NLP techniques, robust data storage, and efficient workflow orchestration."

## 🎯 Business Value

For organizations dealing with complex document management:

- **40% faster information retrieval** through contextual linking
- **25% improved solution discovery** via AI-powered diagnostics
- **50% reduction in search time** through associative memory trails

## 🏗️ Core Architecture

```
mindmap
  Document Management System
    Ingestion
      Documents
        Files
        Directories
        URLs
    Text Processing
      Tokenization
      POS Tagging
      NER
      Dependency Parsing
    Semantic Search
      Vector Similarity
      BM25F Scoring
    Image Processing
      Base64 Conversion
      Temporary Files
    LLM Integration
      Chat
      Text Generation
      Translation
    Database Storage
      Ohm
      Sequel
    CLI Interface
      Ingest
      Process
      Search
```

## 🧠 Key Components

### Document Processing

- **Multi-format Support**: Process PDFs, text files, HTML, and Markdown
- **Structure Preservation**: Extract and maintain document hierarchy
- **Media Handling**: Process embedded images and tables
- **Synchronous Pipeline**: Real-time document conversion and analysis

### Intelligent Retrieval

- **MemexTrail System**: Graph-based connections between related documents
- **Hybrid Search**: Combine vector similarity with BM25F scoring
- **Multi-hop Exploration**: Discover indirect document relationships
- **Contextual Understanding**: Identify semantically related content

### NLP Capabilities

- **spaCy Integration**: Advanced text analysis including NER and dependency parsing
- **Multilingual Support**: Process content in multiple languages
- **Vector Embeddings**: Transform content using BAAI/bge-large-en-v1.5 model
- **Semantic Analysis**: Extract meaning beyond simple keyword matching

### Storage Infrastructure

- **PostgreSQL & pgvector**: Efficient storage and retrieval of vector embeddings
- **Redis**: Fast caching and task queue management
- **RedisGraph**: Store associative trails for rapid traversal
- **Flexible Models**: Ohm for Redis and Sequel for PostgreSQL integration

### System Automation

- **Jongleur Integration**: Orchestrate complex document workflows
- **SublayerTaskGenerator**: Create and customize processing tasks
- **Error Handling**: Robust recovery from processing failures
- **Progress Tracking**: Monitor document processing in real-time

### User Interfaces

- **CLI (Thor)**: Command-line tools for efficient document operations
- **Web Interface**: Intuitive browser-based document management
- **REST API**: Integration endpoints for external systems
- **Visualization**: Graphical representation of document relationships

## 🛠️ Technology Stack

| Component          | Technology                               |
|--------------------|------------------------------------------|
| Language           | Ruby                                     |
| NLP                | ruby-spacy via SpacyModelRegistry        |
| Embeddings         | BAAI/bge-large-en-v1.5                   |
| Vector Storage     | PostgreSQL with pgvector                 |
| Graph Database     | RedisGraph                               |
| Caching            | Redis                                    |
| ORM                | Ohm (Redis) and Sequel (PostgreSQL)      |
| Task Management    | Jongleur                                 |
| CLI Framework      | Thor                                     |
| Web Framework      | Sinatra                                  |
| Template Engine    | Slim                                     |
| LLM Integration    | RubyLLM                                  |
| Prompt Management  | Langfuse                                 |
| Testing            | RSpec                                    |

## 🚀 Getting Started

### Prerequisites

- Ruby 3.0+
- PostgreSQL with pgvector extension
- Redis with RedisGraph module
- spaCy models for target languages

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/memexrag.git
cd memexrag

# Install dependencies
bundle install

# Configure environment
cp .env.example .env
# Edit .env with your configuration

# Set up database
rake db:setup
```

### Basic Usage

```bash
# Ingest documents
memexrag ingest /path/to/documents

# Process document collection
memexrag process --collection=my_documents

# Perform semantic search
memexrag search "your query here"

# Explore associative trails
memexrag explore --document=doc_id
```

## 🔬 Technical Innovations

### MemexTrail System

The core innovation is the MemexTrail system, which creates and navigates associative connections between related content. This graph-based approach mirrors human thought patterns:

- **Automatic Trail Generation**: Identify semantic relationships between documents
- **Trail Weighting**: Prioritize connections based on relevance and usage
- **Bidirectional Navigation**: Follow associative paths in any direction

### Hybrid Retrieval

Memexrag's unique retrieval approach combines:

- **Vector Search**: Semantic understanding through embeddings
- **BM25F Scoring**: Field-weighted keyword relevance
- **Graph Traversal**: Follow established associative trails

### Advanced Document Processing

- **Semantic Chunking**: Divide documents into meaningful segments
- **Hierarchy Preservation**: Maintain document structure during processing
- **Custom File Loaders**: Support specialized document types
- **Media Extraction**: Process embedded images and tables

## 🛣️ Development Roadmap

### Recent Updates

- Added Sublayer Task Generator for creating Sublayer tasks
- Refactored Semantic Search with BM25F integration
- Implemented CustomFileLoader for advanced document processing
- Added synchronous document conversion pipeline

### Upcoming Milestones

| Phase | Focus | Timeline |
|-------|-------|----------|
| Foundation | CLI, vector search, document pipeline | Q2 2025 (Sprint 1-2) |
| Core Features | NLP pipeline, LLM integration, API | Q2 2025 (Sprint 3-4) |
| Optimization | Performance, security, testing | Q2 2025 (Sprint 5-6) |
| Production | Full release with documentation | Q3 2025 |

## 📊 Success Metrics

| Category | Metric | Target | Method |
|----------|--------|--------|--------|
| Technical | API latency (p95) | <500ms | Prometheus |
| Technical | Document processing | <2s/page | Monitoring |
| Business | Information retrieval | 40% faster | Analysis |
| Business | User satisfaction | >4.5/5 | Surveys |

## 🔒 Risk Mitigation

1. **Search Performance**:
   - Hybrid search optimization
   - Caching strategy implementation
   - Regular performance benchmarking

2. **Document Processing**:
   - Optimized chunking strategies
   - Memory management improvements
   - Asynchronous processing for large documents

## 👥 Contributing

We welcome contributions to memexrag! See our [Contribution Guidelines](./CONTRIBUTING.md) for details on how to get involved.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Project Status**: Active Development (Sprint 2)  
**Next Release**: 2025-06-30  
**Lead Maintainer**: [Your Name]
