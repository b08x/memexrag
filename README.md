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
- **Langfuse Integration**: Version-controlled prompts with PyCall bridge

#### Interface Layer

- **CLI**: Incident investigation workflows via Thor
- **REST API**: Sinatra endpoints for integration

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

- Dynamic prompt versioning
- A/B testing of diagnostic strategies
- Audit trail for AI decisions

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
| Vector DB         | Redis                       | Low-latency, existing infra alignment|
| Orchestration     | Jongleur                    | Ruby-native DAG support               |

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
**Next Release**: 2024-06-30 (Phase 1 Feature Complete)  
**Lead Maintainer**: [Your Name] | [Contact Info]
