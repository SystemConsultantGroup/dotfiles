---
name: merge-into-downstream
description: Upstream host — propagate upstream changes into a downstream fork you maintain. Uses ephemeral downstream-scratch branch.
---

Push upstream commits **into** a specific downstream fork from the upstream host. Uses an ephemeral `downstream-scratch` branch.

> **Prerequisite:** Upstream host must have a remote pointing to the downstream fork:
> ```bash
> git remote add <downstream> https://github.com/<fork-org>/dotfiles.git
> ```
> Replace `<downstream>` with a short identifier (e.g. `scg`, `client-foo`).

## Workflow

### 1. Review what's new

```bash
git fetch <downstream>
git log --oneline --no-merges <downstream>/master..origin/master
```

### 2. Create scratch branch from downstream

```bash
git checkout -b downstream-scratch <downstream>/master
```

### 3. Merge upstream into scratch

```bash
git merge --no-commit origin/master
```

### 4. Resolve conflicts

| File type | Rule |
|---|---|
| **Fork-specific** (`hosts/<fork-name>/`, fork-specific flake inputs) | Keep downstream version |
| **Generic** (`modules/`, `home/`, `lib/`) | Favor upstream, then re-apply downstream customizations |
| **Hybrid** (`flake.nix`) | Manual merge: keep downstream-only blocks, accept upstream improvements |
| **`flake.lock`** | Take upstream version, then `nix flake lock` |

```bash
git checkout --theirs flake.lock && nix flake lock && git add flake.lock
```

### 5. Build

```bash
nh os build .
```

### 6. Commit and push

```bash
git commit -m "chore: merge upstream into <downstream>"
git push <downstream> downstream-scratch:master
```

### 7. Clean up

```bash
git checkout master
git branch -d downstream-scratch
```

---

## Recovery

```bash
git merge --abort              # undo staged merge
git checkout master            # abandon scratch
git branch -D downstream-scratch
```
