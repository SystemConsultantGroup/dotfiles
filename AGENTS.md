# NixOS dotfiles agent

You manage a flake-based NixOS configuration for a single host (`workstation`). You are self-contained: you implement, validate, commit, and push directly.

## Repository layout

- `flake.nix` — inputs (nixpkgs, the kime fork, persway), user-specific values in the `let` block (`username`, `userFullName`, `gitUserName`, `gitUserEmail`), host wiring, formatter, devshell
- `hosts/workstation/` — host entry point plus the generated hardware config
- `modules/base/` — system-wide config (nix, networking, user, bash, git, ssh)
- `modules/desktop/` — GUI stack (sway, noctalia, greetd, kime, pipewire, fonts, apps)
- `modules/drivers/` — per-GPU driver modules (currently `arc.nix`)
- `files/` — user-facing configs as plain files (sway, noctalia `config.toml`, alacritty `alacritty.toml`, wallpapers); modules reference them with `builtins.readFile` or `environment.etc.<name>.source`
- `patches/` — upstream patches applied at build time (persway layout fix); pinned to the flake.lock rev, so regenerate when that input bumps

## Core conventions

- No `with pkgs;` or `with lib;` — always explicit `pkgs.` / `lib.` prefixes
- No home-manager: all packages go in `environment.systemPackages` (single-user box, no per-user profile)
- User-specific values are defined once in `flake.nix`'s `let` block; forking requires editing only that file
- Branch: `master` (not `main`)
- Configs live as plain files under `files/**` so they are diffable and editor-native, never Nix string literals

## Build & validation

| What changed | Validate with |
| --- | --- |
| Nix files (`modules/`, `hosts/`, `flake.nix`) | `statix check . && deadnix . && nix fmt`, then `nh os build .` |
| Sway config (`files/sway/config`) | `sway -C -c <config path>` (capital `-C`; `--validate` does not work) |

- Lint warnings are errors: `statix` and `deadnix` must pass clean. Build warnings from our own code during `nh os build` are also errors.
- Upstream nixpkgs deprecation warnings during `nh os build` are fine.
- Fix on failure: read the error, fix the source file, and retry. Never report a failure without at least one fix attempt.

## Workflow

- Break changes into small, cherry-pickable commits, one logical concern per commit
- Conventional-commits prefixes (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`)
- Run the gates before committing, `nh os switch .` after the change, then push
- Push after every successful change unless the user explicitly asks for a dry-run or WIP
- Don't discard unrecognized changes: pre-existing uncommitted work is intentional (user or parallel agent). Never `git stash`, `git reset --hard`, or `git clean` without explicit instruction. Integrate your work alongside theirs.
- Never oneshot URLs: search the web for the correct URL before fetching. Guessed URLs are often 404s or stale.
- Ask only at irreversible forks (architectural choices, changes beyond the request); otherwise execute.
