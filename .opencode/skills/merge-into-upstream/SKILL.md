---
name: merge-into-upstream
description: Generalize SCG downstream work and push generic improvements to the upstream template (apersomany/dotfiles)
---

Generalize SCG downstream work and push it to the upstream template (`apersomany/dotfiles`).

Use this when you made changes on the SCG fork (`SCG/dotfiles`, `master` branch) and realize those changes have generic value that belongs in the template — e.g., a module refactor, a new tooling config, a bug fix, or a workflow improvement.

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

### 1. Identify downstream commits to generalize

```bash
# See what SCG has that upstream doesn't
git log --oneline --no-merges upstream/master..master
```

Pick the commits that contain generic improvements. SCG-only commits (router config, NVIDIA driver fixes, branding changes) should **never** go upstream.

### 2. Sync upstream branch

```bash
git checkout upstream
git pull upstream master  # ensure latest template state
```

### 3. Cherry-pick the relevant commits

```bash
git cherry-pick <commit-hash1> <commit-hash2> ...
```

If a commit touches both generic and SCG-specific files, handle it:

- **For files that are entirely SCG-specific** (`hosts/router/*`): during cherry-pick, discard those changes with `git checkout --ours <file>` and `git add <file>`.
- **For hybrid files** (e.g., `flake.nix` containing both `scg` user values and generic imports): manually edit to remove SCG-specific sections — replace `scg` user values with the template's `username` variable, remove router inputs, etc.

### 4. Strip SCG-specific content

After cherry-picking, audit the changes for any remaining SCG-specific content that must be removed or generalized:

| Pattern | SCG value | Template replacement |
|---|---|---|
| `flake.nix` username | `"scg"` | `username` (from `let` block) |
| `flake.nix` userFullName | `"SCG User"` | `"NixOS User"` |
| `flake.nix` gitUserName | `"SCG"` | `"nixos-user"` |
| `flake.nix` gitUserEmail | `"scg@example.com"` | `"user@example.com"` |
| Router-specific modules | `hosts/router/*` imports | Remove entirely |
| NVIDIA-specific config | `nvidia-offload`, `nvidia-docker`, etc. | Remove unless generic (e.g., standard `nvidia` module) |
| SCG branding/names | Any `SCG` string in docs/config | Remove or replace with generic terms |

### 5. Build check

```bash
nh os build .
```

Must succeed on `upstream` branch. If it fails, the changes aren't sufficiently generic yet — fix and rebuild.

### 6. Format

```bash
nix fmt
git add -A
git commit --amend --no-edit  # include formatted changes
```

### 7. Push to template

```bash
git push upstream upstream:master  # → apersomany/dotfiles
```

### 8. Merge back to SCG downstream

```bash
git checkout master
git merge upstream
nh os build .
git push origin master  # → SCG/dotfiles
```

This ensures SCG stays in sync with the template it just contributed to.

## Example: generalizing a SCG module improvement

Suppose you added a new tool config to `modules/tools/default.nix` on `master`:

```bash
# 1. Find the commit
git log --oneline -5 master

# 2. Pull latest template
git checkout upstream
git pull upstream master

# 3. Cherry-pick
git cherry-pick abc1234

# 4. Check for SCG-specific content (none in this case — it's a pure module change)
# 5. Build
nh os build .

# 6. Format and push
nix fmt
git add -A
git commit --amend --no-edit
git push upstream upstream:master

# 7. Merge back
git checkout master
git merge upstream
git push origin master
```

## Recovering from a bad generalisation

```bash
# Abort an in-progress cherry-pick
git cherry-pick --abort

# Undo commits already pushed to upstream (use with caution)
git reset --hard HEAD~N
git push upstream upstream:master --force  # last resort, coordinate with other upstream users
```
