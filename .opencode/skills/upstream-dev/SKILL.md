---
name: upstream-dev
description: For upstream host — develop changes on the canonical repo (apersomany/dotfiles)
---

Make changes on the upstream host (`origin → apersomany/dotfiles`). Simple, linear workflow — no downstream verification needed.

## Workflow

```bash
# make changes on master
nh os build .
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
- If this change could affect downstream forks (module refactors, flake input changes), consider notifying downstream maintainers or following up with `upstream-merge` if you maintain any downstreams yourself.
- If the change is breaking (renames, moves, module refactors), update `.opencode/agents/NixOS.md` and the relevant skill files.
