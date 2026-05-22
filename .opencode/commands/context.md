---
description: Inject workspace context — hostname, git state, directory tree
---

## Workspace Context

**Host:** !`hostname`

**Git remote:** !`git remote get-url origin 2>/dev/null || echo 'no remote'`

**Git branch:** !`git rev-parse --abbrev-ref HEAD 2>/dev/null`

**Recent commits:**
!`git log --oneline -5 2>/dev/null || echo 'no commits'`

**Git status:**
!`git status --short 2>/dev/null || echo 'clean'`

**Directory tree (top 3 levels):**
!`find . -maxdepth 3 -type d | head -40 | sort`
