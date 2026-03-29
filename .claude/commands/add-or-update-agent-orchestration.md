---
name: add-or-update-agent-orchestration
description: Workflow command scaffold for add-or-update-agent-orchestration in memexrag.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /add-or-update-agent-orchestration

Use this workflow when working on **add-or-update-agent-orchestration** in `memexrag`.

## Goal

Adds or refactors agent orchestration logic, often integrating prompt management, tool support, or workflow generation.

## Common Files

- `lib/memexrag/agents/agent.rb`
- `lib/memexrag/agents/orch.rb`
- `lib/memexrag/agents/multi-agent-workflow-gen.rb`
- `lib/memexrag/clients/langfuse_client.rb`
- `lib/memexrag/clients/dify_client.rb`
- `lib/memexrag/commands/promptlist.rb`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Edit or add files in lib/memexrag/agents/ (e.g., agent.rb, orch.rb, multi-agent-workflow-gen.rb)
- Edit or add files in lib/memexrag/clients/ (e.g., langfuse_client.rb, dify_client.rb)
- Optionally update lib/memexrag/commands/ (e.g., promptlist.rb, ingest.rb)
- Optionally update lib/memexrag/processors/multilingual.rb or related processor files
- Update or add documentation or markdown files if needed

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.