---
name: downstream-dev
description: For downstream fork hosts — develop changes (generic or fork-specific), verify on downstream before pushing upstream, PR fallback if no upstream push access
---

Make changes on a downstream fork. Two paths depending on whether the change is generic (belongs in upstream) or fork-specific.

> **Prerequisite:** The fork must have `upstream` remote configured pointing to `apersomany/dotfiles` and a local `upstream` branch tracking `upstream/master`:
> ```bash
> git remote add upstream https://github.com/apersomany/dotfiles.git
> git fetch upstream
> git branch upstream upstream/master
> ```

---

## Decision: generic or fork-specific?

Before touching code, classify the change:

| Category | Examples | Path |
|---|---|---|
| **Generic** | Module refactors, package fixes, tooling configs (`modules/`, `home/`, `lib/`), UI improvements, workflow docs | [Path A](#path-a-generic-change) |
| **Fork-specific** | Router firewall rules, NVIDIA driver, hostname, secrets, branding — anything that only makes sense for *this* fork | [Path B](#path-b-fork-specific-change) |
| **Mixed** | e.g. removing a redundant field from all modules AND updating fork-specific docs | Split: generic part via Path A, fork part via Path B |

---

## Path A: Generic change

Core principle: **develop on upstream, verify on downstream, only then push/PR upstream.** This ensures you never break any downstream fork (including your own) with a change that looked good in isolation.

### Step 1: Sync upstream branch

```bash
git checkout upstream
git pull upstream master
```

### Step 2: Make changes

Make all edits on the `upstream` branch. Stay on this branch — do not switch to `master` until the changes are ready.

- **Never reference fork-specific paths or configs** (e.g. `hosts/router/`, fork-specific flake inputs). The upstream branch must remain fork-agnostic.
- Write against the `username` variable from `flake.nix`'s `let` block, not a hardcoded fork user name.

### Step 3: Build upstream

```bash
nh os build .
```

Fix any build errors. Repeat until clean.

If Hyprland Lua was changed, also run:
```bash
Hyprland --verify-config -c dynamic/hypr/hyprland.lua
```

### Step 4: Test on downstream

```bash
git checkout master
git merge --no-commit upstream    # stages the merge, does NOT create a commit
nh os build .
```

#### If the downstream build passes:

```bash
git commit -m "chore: merge upstream: <brief description>"
```

Proceed to [Step 5](#step-5-format-and-commit-upstream).

#### If the downstream build fails:

```bash
git merge --abort                 # cleanly undo the staged merge
git checkout upstream             # go back to fix
```

Fix the issue. Then repeat:
```bash
nh os build .                     # build upstream
git checkout master
git merge --no-commit upstream    # re-merge downstream
nh os build .                     # build downstream
```

If it fails again: `git merge --abort`, fix on upstream, repeat. Once both pass:

```bash
git commit -m "chore: merge upstream: <brief description>"
```

> **Why `--no-commit`?** It stages the merge without creating a commit, so `--abort` cleanly unwinds it. This avoids accumulating garbage merge commits during the fix loop.

### Step 5: Format and commit upstream

```bash
git checkout upstream
nix fmt
git add -A
git commit -m "fix: <conventional-commit message>"
```

### Step 6: Push upstream (or PR)

```bash
git push upstream upstream:master
```

#### If push succeeds:

Go to [Step 7](#step-7-push-downstream).

#### If push is denied (403, no permission):

You don't have write access to `apersomany/dotfiles`. Fall back to a PR:

```bash
# Push the upstream branch to your fork under a PR branch name
PR_BRANCH="pr/upstream-$(date +%Y%m%d)"
git push origin upstream:$PR_BRANCH

# Open the PR
gh pr create \
  --repo apersomany/dotfiles \
  --head "$(git remote get-url origin | sed 's|.*[:/]\(.*\)/dotfiles.*|\1|'):$PR_BRANCH" \
  --base master \
  --title "<commit message subject>" \
  --body "$(cat <<'EOF'
## Summary

<1-3 bullet points describing the change>

## Verification

- [ ] Builds on upstream (`nh os build .`)
- [ ] Builds on downstream after merge (`nh os build .`)
EOF
)"
```

> **Note:** The `--head` format is `<fork-org>:<branch>`. If `git remote get-url origin` doesn't parse cleanly, run `gh repo view --json nameWithOwner -q .nameWithOwner` to get the fork's org/repo and construct `org:pr/upstream-XXXX` manually.

### Step 7: Push downstream

```bash
git checkout master
git push origin master
```

This always succeeds since you own the fork.

---

## Path B: Fork-specific change

Simpler — changes never leave the fork.

```bash
git checkout master
# make changes
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

## Merge conflict handling

During `git merge --no-commit upstream` on `master`, conflicts may arise. Resolve as follows:

| File type | Rule |
|---|---|
| **Fork-specific** (`hosts/<fork-name>/`, fork-specific flake inputs) | Keep `master` version |
| **Generic** (`modules/`, `home/`, `lib/`) | Favor `upstream` version, then re-apply any fork customizations |
| **Hybrid** (`flake.nix`, files importing from both `modules/` and fork-specific paths) | Manual merge: keep fork-only blocks, accept upstream generic improvements |
| **`flake.lock`** | Regenerate with `nix flake lock` — do not resolve manually |

When in doubt: favor upstream for generic code paths, downstream for fork-specific code paths.

### Regenerating flake.lock

If `flake.lock` had conflicts (or upstream changed flake inputs):

```bash
git checkout --theirs flake.lock   # take upstream version as base
nix flake lock                      # regenerate
git add flake.lock
```

---

## Recovery

```bash
git merge --abort              # undo an in-progress --no-commit merge
git checkout -- .              # discard uncommitted workspace changes
git reset --hard ORIG_HEAD     # undo a committed merge (before pushing)
```
