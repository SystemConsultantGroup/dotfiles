---
name: plan
description: Create a concise PLAN.md in the current project from the request and inspected context. Use when the user prefixes a request with plan:.
---

# Plan

Write a `PLAN.md` in the current working directory based on the user's request and the relevant repository context.

- Inspect the relevant files, conventions, and validation commands before writing.
- Include the goal, current context, implementation steps, validation, non-goals, and open decisions.
- Keep the plan concrete and ordered; do not invent requirements.
- Create or update only `PLAN.md`; do not implement the plan unless the user separately asks.
- Report the path and a short summary after writing it.
