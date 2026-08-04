---
name: delegate
description: Delegate all work to subagents and only orchestrate their progress, decisions, implementation, and validation. Use when the user prefixes a request with delegate:.
---

# Delegate

Delegate the entire request to subagents. Do not perform the work directly.

- Inspect available agents with `subagent({ action: "list" })` before launching work.
- Choose the smallest workflow that covers the request; use one writer for a shared worktree.
- Delegate discovery, planning, implementation, and validation as needed.
- Stay the parent orchestrator: synthesize results, resolve decisions, supervise status, and report outcomes.
- Do not edit files, run project commands, or do the delegated task yourself unless required to supervise the run.
- Preserve the user's scope and constraints, and escalate unresolved decisions instead of guessing.
