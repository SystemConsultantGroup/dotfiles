---
name: downstream-merge
description: For downstream fork hosts — merge upstream changes someone else made into your fork
---

Pull upstream commits that were made by someone else (or by you from the upstream host) into your downstream fork.

> This is for **external** upstream changes — commits you did not author in this session. For changes you are making yourself, use `downstream-dev` instead.

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

Understand the scope to anticipate conflicts.

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
| **`flake.lock`** | Take upstream version as base, then `nix flake lock` |

If `flake.lock` had conflicts:
```bash
git checkout --theirs flake.lock
nix flake lock
git add flake.lock
```

### 5. Build

```bash
nh os build .
```

If the build fails, fix the issues, stage them, then:
```bash
git merge --continue              # if still in merge state
# or
git commit -m "chore: merge upstream into downstream"
```

### 6. Commit and push

```bash
git commit -m "chore: merge upstream into downstream"
git push origin master
```

---

## Selective (cherry-pick) variant

If you only want specific upstream commits rather than everything:

```bash
git checkout master
git pull origin master
git cherry-pick <hash1> <hash2> ...
# resolve conflicts per the table above
nh os build .
git push origin master
```

---

## Recovery

```bash
git merge --abort              # undo an in-progress merge
git merge --continue           # resume after fixing conflicts
git reset --hard ORIG_HEAD     # undo a committed merge (before pushing)
```
