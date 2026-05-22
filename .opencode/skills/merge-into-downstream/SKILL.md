---
name: merge-into-downstream
description: Merge upstream template commits (apersomany/dotfiles) into the SCG downstream (SCG/dotfiles)
---

Merge upstream template commits (`apersomany/dotfiles`) into the SCG downstream (`SCG/dotfiles`).

Use this when you've been working on the upstream template repo (or upstream has received new commits) and need to bring those improvements into the SCG fork.

## Prerequisites

Already set up in SCG fork mode:
- `origin` → `SCG/dotfiles` (downstream)
- `upstream` → `apersomany/dotfiles` (template)
- Local `upstream` branch tracking `upstream/master`

If not, run:
```bash
git remote rename origin upstream
git remote add origin https://github.com/SystemConsultantGroup/dotfiles
git fetch upstream
git branch upstream upstream/master
```

## Workflow

### 1. Scope the commits

```bash
# See what upstream has that SCG doesn't
git log --oneline --no-merges origin/master..upstream/master
```

Review the list to understand what's coming. This helps anticipate conflicts.

### 2. Merge upstream into downstream

```bash
git checkout master
git pull origin master  # ensure latest SCG state
git merge upstream
```

If the merge succeeds cleanly, skip to step 5.

### 3. Resolve conflicts

| File type | Rule | Examples |
|---|---|---|
| **SCG-specific** | Keep SCG (`master`) version | `hosts/router/*` |
| **Generic** | Favor upstream, then re-apply SCG customizations | `modules/*`, `home/*`, `lib/*` |
| **Hybrid** | Manual merge — keep SCG blocks, accept upstream generic improvements | `hosts/router/configuration.nix`, `flake.nix` |
| **Auto-generated** | Regenerate rather than merge | `flake.lock` |

Common conflict patterns:

- **`flake.nix`**: SCG adds router inputs (`nixos-router`, `notnft`) + changes user values (`scg`). Upstream adds tooling inputs. Merge to keep both.
- **`dynamic/hypr/hyprland.conf`**: Upstream migrates to Lua. SCG may still reference `.conf`. Resolve in favor of Lua (`git rm`).
- **`.opencode/agents/NixOS.md`**: Hybrid content. Merge SCG-specific push instructions with upstream workflow improvements.

### 4. Regenerate lock file

```bash
# If flake.lock had conflicts:
nix flake lock
```

### 5. Stage & commit

```bash
git add -A
git status  # verify everything is intentional
git commit -m "chore: merge upstream template into downstream"
```

### 6. Build check

```bash
nh os build .
```

Only if Nix files were changed.

### 7. Push

```bash
git push origin master  # → SCG/dotfiles
```

Only push to `origin`. The merge itself is SCG-specific — upstream already has these commits.

> **Never force push to master.** If the merge introduces issues, fix on a separate branch first.

## Cherry-pick variant (selective merge)

If you only want specific commits rather than the full upstream branch:

```bash
git checkout master
git pull origin master
git cherry-pick <commit-hash1> <commit-hash2> ...
# resolve conflicts per the table above
nh os build .
git push origin master
```

Useful when upstream has many experimental commits you don't want downstream yet.

## Recovering from a bad merge

```bash
git merge --abort       # revert to pre-merge state
# or after commit:
git reset --hard ORIG_HEAD  # undo the merge commit
```
