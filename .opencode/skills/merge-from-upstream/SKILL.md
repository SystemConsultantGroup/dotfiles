---
name: merge-from-upstream
description: Downstream host — pull upstream changes into your fork. Uses ephemeral upstream-scratch branch. Works for anyone with a fork.
---

Pull upstream commits (made by someone else, or by you from the upstream host) **from** upstream into your downstream fork.

Uses an ephemeral `upstream-scratch` branch — created, used, and deleted within this workflow.

> **Prerequisite:** Fork must have `upstream` remote pointing to `apersomany/dotfiles`:
> ```bash
> git remote add upstream https://github.com/apersomany/dotfiles.git
> ```

## Workflow

### 1. Review what's coming

```bash
git fetch upstream
git log --oneline --no-merges origin/master..upstream/master
```

### 2. Create scratch branch from upstream

```bash
git checkout -b upstream-scratch upstream/master
```

### 3. Merge into downstream (staged)

```bash
git checkout master
git pull origin master              # ensure latest fork state
git merge --no-commit upstream-scratch  # stage, don't commit
```

### 4. Resolve conflicts (if any)

| File type | Rule |
|---|---|
| **Fork-specific** (`hosts/<fork-name>/`, fork-specific flake inputs) | Keep `master` version |
| **Generic** (`modules/`, `home/`, `lib/`) | Favor scratch, then re-apply fork customizations |
| **Hybrid** (`flake.nix`) | Manual merge: keep fork-only blocks, accept upstream improvements |
| **`flake.lock`** | Take scratch version, then `nix flake lock` |

```bash
git checkout --theirs flake.lock && nix flake lock && git add flake.lock
```

### 5. Build

```bash
nh os build .
```

### 6. Commit and push

```bash
git commit -m "chore: merge upstream into downstream"
git push origin master
```

### 7. Clean up

```bash
git branch -d upstream-scratch
```

---

## Selective (cherry-pick) variant

If you only want specific upstream commits:

```bash
git fetch upstream
git checkout -b upstream-scratch upstream/master  # for reference / conflict resolution
git checkout master
git cherry-pick <hash1> <hash2> ...
# resolve conflicts per table above
nh os build .
git push origin master
git branch -d upstream-scratch
```

---

## Recovery

```bash
git merge --abort              # undo staged merge
git reset --hard ORIG_HEAD     # undo committed merge (before pushing)
git branch -d upstream-scratch # clean up
```
