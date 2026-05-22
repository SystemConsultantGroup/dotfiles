---
name: merge-from-downstream
description: Upstream host — pull downstream innovations back into upstream. Cherry-pick or merge specific downstream improvements, strip fork-specific content, push upstream.
---

Pull improvements **from** a downstream fork back into the upstream (`apersomany/dotfiles`). Use this when a downstream fork has made a valuable generic improvement that belongs upstream.

> This is the reverse of `merge-into-upstream`. Instead of the downstream pushing up, the upstream pulls down.

## Prerequisite

Upstream host must have the downstream fork as a remote:

```bash
git remote add <downstream> https://github.com/<fork-org>/dotfiles.git
git fetch <downstream>
```

## Workflow

### 1. Identify what to pull

```bash
git fetch <downstream>
git log --oneline --no-merges origin/master..<downstream>/master
```

Pick commits that contain generic improvements. Fork-specific commits (router config, NVIDIA driver, branding) should **never** be pulled.

### 2. Cherry-pick (recommended — selective)

```bash
git cherry-pick <hash1> <hash2> ...
```

### 3. Strip fork-specific content

Audit the cherry-picked changes for downstream-specific content that must be removed or generalized:

| Pattern | Downstream value | Upstream replacement |
|---|---|---|
| `flake.nix` username | Fork-specific (e.g. `"scg"`) | `username` (from `let` block) |
| `flake.nix` user values | Fork-specific names/emails | Generic defaults |
| Fork-specific modules | `hosts/<fork-name>/*` imports | Remove entirely |
| Fork-specific hardware | NVIDIA, router configs | Remove unless truly generic |
| Fork branding | Any fork-specific strings in docs/config | Remove or replace with generic terms |

### 4. Build

```bash
nh os build .
```

### 5. Format and commit

```bash
nix fmt
git add -A
git commit -m "refactor: pull <description> from <downstream>"
```

### 6. Push

```bash
git push origin master
```

---

## Full merge variant (pull everything — riskier)

If you want ALL downstream changes (useful when a downstream has diverged significantly):

```bash
git checkout -b pull-from-<downstream>
git merge --no-commit <downstream>/master
# Manually strip all fork-specific content (see table above)
# Resolve any conflicts favoring upstream for generic files
nh os build .
nix fmt
git add -A
git commit -m "refactor: merge improvements from <downstream>"
git checkout master && git merge pull-from-<downstream>
git push origin master
git branch -d pull-from-<downstream>
```

---

## Recovery

```bash
git cherry-pick --abort        # abort in-progress cherry-pick
git merge --abort              # abort in-progress merge
git reset --hard HEAD~N        # undo committed cherry-picks (before pushing)
```
