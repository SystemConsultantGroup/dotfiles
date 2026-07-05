# Agent Environment: NixOS (flake-based)

You are running on **NixOS** with a flake-based declarative configuration. This
file gives you the environment-specific conventions that apply to *every* project
on this machine. Projects may ship their own `AGENTS.md` with additional rules —
those are loaded on top of this one.

## System facts

- **OS**: NixOS 26.11, immutable & declarative
- **User**: `aperso` — home at `/home/aperso`
- **Dotfiles / system flake**: `~/dotfiles`
- **pi itself**: launched via `bunx @earendil-works/pi-coding-agent`; its config
  lives in `~/.pi/agent/` (symlinked from `~/dotfiles/dynamic/pi-agent/`)

## Package management — the golden rule

**Never use `apt`, `dnf`, `brew`, `pacman`, `pip install` (global), `npm i -g`,
or `nix-env -iA` to install software.** The system is declarative; ad-hoc installs
do not survive a rebuild and pollute the profile.

- **Permanent CLI tools / apps** → add them to the flake's `home.packages` (or
  `environment.systemPackages` for system-level needs) and rebuild.
- **One-off / throwaway tools** → use a temporary shell, no install:
  ```bash
  nix run nixpkgs#<pkg>        # run without installing
  nix shell nixpkgs#<pkg>      # drop into a shell with <pkg>
  nix shell nixpkgs#<a> nixpkgs#<b>   # multiple
  ```

## Python & JS

- **Python** → `uv` is available; use project venvs (`uv sync`, `uv pip`).
  Do not `pip install` into the system interpreter.
- **JavaScript** → `bun` is available. For project work use the
  project's lockfile (`bun install`), not global installs.

## Useful tools already on PATH

`nh` (NixOS helper), `nix`, `statix`, `deadnix`, `bun`/`bunx`, `uv`, `rg` (ripgrep), `fd`, `fzf`, `jq`, `bat`, `gh`, `git`, `direnv`.

## When a command is missing

If a tool you need isn't installed, prefer `nix shell nixpkgs#<tool>` for the
current session rather than failing or asking the user to install it. Only add
it permanently to the flake if the project genuinely depends on it.
