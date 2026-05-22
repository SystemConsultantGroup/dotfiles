---
name: upstream-merge
description: For upstream host — propagate upstream changes into a downstream fork. Optional — only needed if you maintain downstream forks from the upstream host.
---

Propagate upstream commits into a specific downstream fork from the upstream host. This requires the upstream host to have a remote pointing to the downstream fork.

> **This skill is optional.** Most upstream hosts don't maintain downstream forks directly. Downstream forks can pull updates themselves using `downstream-merge`.

## Prerequisite

Add the downstream fork as a remote (one-time setup per downstream):

```bash
git remote add <downstream-name> https://github.com/<fork-org>/dotfiles.git
git fetch <downstream-name>
```

Replace `<downstream-name>` with a short identifier for the fork (e.g. `scg`, `client-foo`). Replace `<fork-org>` with the GitHub org/user that owns the fork.

## Workflow

### 1. Review what's new

```bash
git log --oneline --no-merges <downstream-name>/master..origin/master
```

### 2. Fetch latest downstream state

```bash
git fetch <downstream-name>
```

### 3. Create a merge branch from downstream

```bash
git checkout -b merge-to-<downstream-name> <downstream-name>/master
```

### 4. Merge upstream

```bash
git merge --no-commit origin/master
```

### 5. Resolve conflicts (if any)

| File type | Rule |
|---|---|
| **Fork-specific** (`hosts/<fork-name>/`, fork-specific flake inputs) | Keep downstream version |
| **Generic** (`modules/`, `home/`, `lib/`) | Favor upstream, then re-apply downstream customizations |
| **Hybrid** (`flake.nix`) | Manual merge: keep downstream-only blocks, accept upstream improvements |
| **`flake.lock`** | Take upstream version as base, then `nix flake lock` |

If `flake.lock` had conflicts:
```bash
git checkout --theirs flake.lock
nix flake lock
git add flake.lock
```

### 6. Build

```bash
nh os build .
```

Fix any build errors before proceeding.

### 7. Commit and push

```bash
git commit -m "chore: merge upstream into <downstream-name>"
git push <downstream-name> merge-to-<downstream-name>:master
```

### 8. Clean up

```bash
git checkout master
git branch -d merge-to-<downstream-name>
```

---

## Recovery

```bash
git merge --abort              # undo an in-progress merge
git checkout master            # abandon the merge branch
git branch -D merge-to-<downstream-name>
```
