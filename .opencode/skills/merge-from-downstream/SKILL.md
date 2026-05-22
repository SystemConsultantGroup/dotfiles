---
name: merge-from-downstream
description: Upstream host — pull downstream innovations back into upstream. Cherry-pick specific improvements, strip fork-specific content, push upstream.
---

Pull improvements **from** a downstream fork back into upstream (`apersomany/dotfiles`). Use when a downstream has a valuable generic improvement that belongs upstream.

> **Prerequisite:** Upstream host must have a remote pointing to the downstream fork:
> ```bash
> git remote add <downstream> https://github.com/<fork-org>/dotfiles.git
> ```

## Workflow

### 1. Identify what to pull

```bash
git fetch <downstream>
git log --oneline --no-merges origin/master..<downstream>/master
```

Pick commits with generic value. Fork-specific commits (router config, NVIDIA driver, branding) should **never** be pulled.

### 2. Cherry-pick (recommended)

Cherry-pick directly onto `master` — no scratch branch needed:

```bash
git cherry-pick <hash1> <hash2> ...
```

### 3. Strip fork-specific content

Audit cherry-picked changes. Remove or generalize anything downstream-specific:

| Pattern | Downstream value | Upstream replacement |
|---|---|---|
| `flake.nix` username | Fork-specific (e.g. `"scg"`) | `username` (from `let` block) |
| `flake.nix` user values | Fork-specific names/emails | Generic defaults |
| Fork-specific modules | `hosts/<fork-name>/*` imports | Remove entirely |
| Fork-specific hardware | NVIDIA, router configs | Remove unless truly generic |
| Fork branding | Any fork-specific strings | Remove or replace with generic terms |

### 4. Build

```bash
nh os build .
```

### 5. Format and commit

```bash
nix run .#lint
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

If you want ALL downstream changes (only when fork has diverged significantly with generic improvements):

```bash
git fetch <downstream>
git checkout -b downstream-scratch <downstream>/master
git checkout master
git merge --no-commit downstream-scratch
# Manually strip all fork-specific content (see table above)
nh os build .
nix fmt
git add -A
git commit -m "refactor: merge improvements from <downstream>"
git push origin master
git branch -d downstream-scratch
```

---

## Recovery

```bash
git cherry-pick --abort        # abort in-progress cherry-pick
git merge --abort              # abort in-progress merge
git reset --hard HEAD~N        # undo committed cherry-picks (before pushing)
git branch -D downstream-scratch
```
