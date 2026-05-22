---
name: downstream-dev
description: Downstream fork host — make fork-specific changes (router, firewall, NVIDIA, branding, secrets) that never leave the fork
---

Make fork-specific changes on a downstream host. For generic changes that should go upstream, use `merge-into-upstream` instead.

## Decision: fork-specific or generic?

| Category | Examples | Use |
|---|---|---|
| **Fork-specific** | Router firewall rules, NVIDIA driver, hostname, secrets, branding | **this skill** |
| **Generic** | Module refactors, package fixes, tooling configs, UI improvements | `merge-into-upstream` |
| **Mixed** | Both fork-specific and generic parts | Split: generic via `merge-into-upstream`, fork via this skill |

## Workflow

```bash
git checkout master
# make fork-specific changes
nh os build .
nix fmt
git add -A
git commit -m "fix: <conventional-commit message>"
git push origin master
```

If Hyprland Lua was changed, validate first:
```bash
Hyprland --verify-config -c dynamic/hypr/hyprland.lua
```

---

## Notes

- Never reference fork-specific paths or values when working on generic changes. Fork-specific code stays on `master` only.
- For pulling upstream changes someone else made into your fork, use `merge-from-upstream`.
