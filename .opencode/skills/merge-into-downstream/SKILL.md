---
name: merge-into-downstream
description: Upstream host — propagate upstream changes into a downstream fork you maintain. Optional — only if you have downstream push access.
---

Push upstream commits **into** a specific downstream fork from the upstream host. Requires the upstream host to have a remote pointing to the downstream fork.

> **This skill is optional.** Most upstream hosts don't maintain downstream forks directly. Downstreams can pull updates themselves using `merge-from-upstream`.

## Prerequisite

Add the downstream fork as a remote (one-time setup per downstream):

```bash
git remote add <downstream> https://github.com/<fork-org>/dotfiles.git
git fetch <downstream>
```

Replace `<downstream>` with a short identifier (e.g. `scg`, `client-foo`). Replace `<fork-org>` with the GitHub org/user that owns the fork.

## Workflow

### 1. Review what's new

```bash
git log --oneline --no-merges <downstream>/master..origin/master
```

### 2. Fetch latest downstream state

```bash
git fetch <downstream>
```

### 3. Create a merge branch from downstream

```bash
git checkout -b merge-to-<downstream> <downstream>/master
```

### 4. Merge upstream

```bash
git merge --no-commit origin/master
```

### 5. Resolve conflicts

| File type | Rule |
|---|---|
| **Fork-specific** (`hosts/<fork-name>/`, fork-specific flake inputs) | Keep downstream version |
| **Generic** (`modules/`, `home/`, `lib/`) | Favor upstream, then re-apply downstream customizations |
| **Hybrid** (`flake.nix`) | Manual merge: keep downstream-only blocks, accept upstream improvements |
| **`flake.lock`** | Take upstream version, then `nix flake lock` |

```bash
git checkout --theirs flake.lock && nix flake lock && git add flake.lock
```

### 6. Build

```bash
nh os build .
```

### 7. Commit and push

```bash
git commit -m "chore: merge upstream into <downstream>"
git push <downstream> merge-to-<downstream>:master
```

### 8. Clean up

```bash
git checkout master
git branch -d merge-to-<downstream>
```

---

## Recovery

```bash
git merge --abort              # undo staged merge
git checkout master            # abandon merge branch
git branch -D merge-to-<downstream>
```
