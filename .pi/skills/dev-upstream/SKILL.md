---
name: dev-upstream
description: Upstream host — make changes on the canonical repo (apersomany/dotfiles), build, format, commit, push. Simple linear workflow.
---

Make changes on the upstream host. Simple, linear — works directly on `master`.

## Workflow

```bash
# make changes on master
nh os build .
statix check . && deadnix .
nix fmt
git add -A
git commit -m "<type>: <description>"
git push origin master
```

If Hyprland Lua was changed, validate first:
```bash
Hyprland --verify-config -c dynamic/hypr/hyprland.lua
```

---

## Notes

- Upstream is a **live, running machine** — build failures here are real breakage, not just CI failures.
- If this change could affect downstream forks, they can pick it up with `merge-from-upstream`.
- To actively push this change to a downstream you maintain, use `merge-into-downstream`.
- To pull downstream innovations back upstream, use `merge-from-downstream`.
- If the change is breaking (renames, moves, module refactors), update `AGENTS.md` and relevant skill files.
