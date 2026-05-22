---
name: merge-from-upstream
description: Downstream fork host — pull upstream changes someone else made into your fork. Simple merge workflow, works for anyone.
---

Pull upstream commits (made by someone else, or by you from the upstream host) **from** upstream into your downstream fork.

> For changes you are authoring yourself, use `merge-into-upstream`. For fork-specific changes, use `downstream-dev`.

## Prerequisite

Fork must have `upstream` remote + local `upstream` branch:
```bash
git remote add upstream https://github.com/apersomany/dotfiles.git
git fetch upstream
git branch upstream upstream/master
```

## Workflow

### 1. Review what's coming

```bash
git log --oneline --no-merges origin/master..upstream/master
```

### 2. Pull latest upstream

```bash
git checkout upstream
git pull upstream master
```

### 3. Merge into downstream (staged)

```bash
git checkout master
git pull origin master              # ensure latest fork state
git merge --no-commit upstream      # stage, don't commit
```

### 4. Resolve conflicts (if any)

| File type | Rule |
|---|---|
| **Fork-specific** (`hosts/<fork-name>/`, fork-specific flake inputs) | Keep `master` version |
| **Generic** (`modules/`, `home/`, `lib/`) | Favor upstream, then re-apply fork customizations |
| **Hybrid** (`flake.nix`) | Manual merge: keep fork-only blocks, accept upstream improvements |
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
git commit -m "chore: merge upstream into downstream"
git push origin master
```

---

## Selective (cherry-pick) variant

```bash
git checkout master
git pull origin master
git cherry-pick <hash1> <hash2> ...
# resolve conflicts per table above
nh os build .
git push origin master
```

---

## Recovery

```bash
git merge --abort              # undo staged merge
git reset --hard ORIG_HEAD     # undo committed merge (before pushing)
```
