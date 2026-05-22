---
name: merge-into-upstream
description: Downstream fork host — develop generic changes, verify on downstream before pushing upstream. PR fallback if no upstream write access.
---

Push generic improvements from a downstream fork back **into** the upstream (`apersomany/dotfiles`).

Core principle: **develop on upstream, verify on downstream, only then push/PR upstream.** This ensures you never break any fork (including your own) with a change that looked good in isolation.

> **Prerequisite:** The fork must have `upstream` remote and local `upstream` branch:
> ```bash
> git remote add upstream https://github.com/apersomany/dotfiles.git
> git fetch upstream
> git branch upstream upstream/master
> ```

---

## Step 1: Sync upstream branch

```bash
git checkout upstream
git pull upstream master
```

## Step 2: Make changes

Make all edits on the `upstream` branch. **Stay on this branch until both builds pass.**

- Never reference fork-specific paths or configs (e.g. `hosts/<fork-name>/`, fork-specific flake inputs).
- Write against the `username` variable from `flake.nix`'s `let` block, not a hardcoded fork user name.

## Step 3: Build upstream

```bash
nh os build .
```

Fix any build errors. Repeat until clean. If Hyprland Lua changed:
```bash
Hyprland --verify-config -c dynamic/hypr/hyprland.lua
```

## Step 4: Verify on downstream

```bash
git checkout master
git merge --no-commit upstream    # stage merge, do NOT create a commit
nh os build .
```

### If downstream build passes:

```bash
git commit -m "chore: merge upstream: <brief description>"
```

Go to [Step 5](#step-5-format-and-commit-upstream).

### If downstream build fails:

```bash
git merge --abort                 # cleanly undo the staged merge
git checkout upstream             # go back to fix
```

Fix the issue. Then loop:
```bash
nh os build .                     # build upstream
git checkout master
git merge --no-commit upstream    # re-stage downstream merge
nh os build .                     # build downstream
```

If it fails again: `git merge --abort`, fix on upstream, repeat. Once both pass:
```bash
git commit -m "chore: merge upstream: <brief description>"
```

> **Why `--no-commit`?** It stages the merge without creating a commit, so `--abort` cleanly unwinds. No garbage merge commits accumulate during the fix loop.

## Step 5: Format and commit upstream

```bash
git checkout upstream
nix fmt
git add -A
git commit -m "fix: <conventional-commit message>"
```

## Step 6: Push upstream (or PR)

```bash
git push upstream upstream:master
```

### If push succeeds:

Go to [Step 7](#step-7-push-downstream).

### If push is denied (403, no permission):

Open a PR instead:

```bash
PR_BRANCH="pr/upstream-$(date +%Y%m%d)"
git push origin upstream:$PR_BRANCH

gh pr create \
  --repo apersomany/dotfiles \
  --head "$(gh repo view --json nameWithOwner -q .nameWithOwner | cut -d/ -f1):$PR_BRANCH" \
  --base master \
  --title "<commit message subject>" \
  --body "$(cat <<'EOF'
## Summary
<1-3 bullet points>
## Verification
- [ ] Builds on upstream (`nh os build .`)
- [ ] Builds on downstream after merge (`nh os build .`)
EOF
)"
```

## Step 7: Push downstream

```bash
git checkout master
git push origin master
```

---

## Merge conflict handling

During `git merge --no-commit upstream` on `master`:

| File type | Rule |
|---|---|
| **Fork-specific** (`hosts/<fork-name>/`, fork-specific flake inputs) | Keep `master` version |
| **Generic** (`modules/`, `home/`, `lib/`) | Favor `upstream` version, then re-apply fork customizations |
| **Hybrid** (`flake.nix`) | Manual merge: keep fork-only blocks, accept upstream improvements |
| **`flake.lock`** | Take upstream version, then `nix flake lock` |

```bash
git checkout --theirs flake.lock && nix flake lock && git add flake.lock
```

---

## Recovery

```bash
git merge --abort              # undo staged --no-commit merge
git checkout -- .              # discard uncommitted workspace changes
git reset --hard ORIG_HEAD     # undo committed merge (before pushing)
```
