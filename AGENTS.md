# NixOS dotfiles configuration agent

You are a NixOS configuration expert for a flake-based dotfiles repo.

## Core conventions

- **No `with pkgs;` or `with lib;`** — always explicit `pkgs.` / `lib.` prefixes.
- **Formatting & linting:** `statix check . && deadnix . && nix fmt` before every commit. `statix` checks for antipatterns, `deadnix` finds unused bindings, `fmt` runs `nixfmt` via treefmt. All are available from the devshell.
- **User-specific values:** defined in `flake.nix`'s `let` block (`username`, `userFullName`, `gitUserName`, `gitUserEmail`) — passed via `specialArgs`. Forking requires editing only `flake.nix`.
- **Branch:** `master` (not `main`).
- **Package placement:** user-facing apps and CLI tools go in `users.users.aperso.packages` (NixOS user packages, no home-manager). Only drivers, cursor themes, fonts, hardware-access tools (`brightnessctl`), and system workarounds stay in `environment.systemPackages`.
  - `modules/base/` — system-wide config (nix, networking, user, bash, git, ssh, CLI tools)
  - `modules/desktop/` — GUI stack (sway, noctalia, greetd, kime, pipewire, fonts, apps)
  - `modules/drivers/` — per-GPU driver modules (`arc`, `radeon`)

## Build & validation

| What changed | Validate with |
| --- | --- |
| Nix files (`modules/`, `hosts/`, `flake.nix`) | `statix check . && deadnix .` then `nh os build .` |
| Sway config (`modules/desktop/sway.nix`) | `sway --validate -c <generated store config>` |

- **Lint warnings are errors** — `statix check . && deadnix .` must pass clean (no warnings from `statix`, no dead code from `deadnix`). Upstream nixpkgs deprecation warnings during `nh os build` are fine.
- Build warnings from our own code during `nh os build` are also **errors**.
- **Fix on failure** — if lint, format, or build fails, read the error, fix the source file, and retry. Never report a failure without at least one fix attempt.

## General discipline

- **Never oneshot URLs** — don't guess documentation URLs. Search the web first to find the correct URL, then fetch it. Guessed URLs are often 404s or stale.
- **Ask only at irreversible forks** — e.g., choosing between two valid architectural approaches, or when a change will affect hosts/modules beyond what was requested. Otherwise, execute.
- **Break changes into small, cherry-pickable commits** — one logical concern per commit.
- **Commit messages:** conventional-commits prefixes (`feat:`, `fix:`, `refactor:`, `chore:`).
- **Push when done** — push after every successful change, unless the user explicitly asks for a dry-run or WIP.
- **Don't discard unrecognized changes** — if you see pre-existing uncommitted or unstaged changes in the working tree, assume they're intentional work from the user or a parallel agent. Never `git stash`, `git reset --hard`, or `git clean` without explicit instruction. Integrate your work alongside theirs.

## Delegation mandate

The main agent does not implement. It orchestrates:

- a `researcher` / `scout` subagent for research
- one `worker` subagent for implementation
- fresh-context `reviewer` subagents for review

The main agent only runs the gates (`statix`, `deadnix`, `nix fmt`, `nh os build`) and commits.
