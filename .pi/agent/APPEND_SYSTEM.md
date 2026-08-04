# SYSTEM_ENV: NixOS (Flake/Declarative)

**Core Directive:** You operate on an immutable, declarative NixOS 26.11 system. Ad-hoc global mutations are strictly forbidden. System conventions supersede project-level `AGENTS.md` rules.

## 1. Context & Identity

- **User:** `aperso` (`/home/aperso`)
- **System Flake:** `~/dotfiles`
- **Agent Config:** `~/.pi/agent/`
- **Code Style:** Write strictly self-explanatory code with clear, descriptive variable names. Comment only when necessary to explain non-obvious "why" logic, never the "what".
- **No Decorative Separators:** Never write `=`, `-`, or any other character as decorative separator lines, banners, or borders, in comments, in code, or in output. If a visual break is genuinely needed, use a blank line.

## 2. The Golden Rule: Package Management

**FORBIDDEN:** `apt`, `dnf`, `brew`, `pacman`, `pip install` (global), `npm i -g`, `nix-env`.

- **Ephemeral / Missing Tools (Default):** Never fail or ask the user to install a missing command. Spawn it dynamically instead:
  - `nix run nixpkgs#<pkg>` (execute directly)
  - `nix shell nixpkgs#<pkg>` (interactive shell)
- **Permanent Tools:** Add explicitly to the flake (`users.users.<name>.packages` or `environment.systemPackages`) and rebuild.

## 3. Sandboxed Ecosystems

- **Python:** Strictly `uv` with project venvs (`uv sync`, `uv pip`). No global `pip`.
- **JavaScript / Node:** Strictly `pnpm` with local lockfiles (`pnpm install`). No global `npm` or `yarn`.

## 4. Execution & Bash Etiquette

- **No Piped Logging:** Never pipe `tail`, `head`, or `grep` directly on bash calls unless they are expected to return semi-instantly.
- **Temp Files First:** If a command takes time, redirect its output to `/tmp/` (e.g. `command > /tmp/cmd_output.log 2>&1`), then inspect the file. The only exception is output guaranteed to be 100GB+.

## 5. Analysis & Debugging Strategy

- **Dynamic > Static:** Do not fall into long chains of static analysis unless the code takes forever to execute. Dynamic analysis is key to quick resolution.
- **Get Your Hands Dirty:** Do not fear attaching debuggers or injecting aggressive `print`/`console.log`/`debug` statements into the code.
- **Cleanup via Git:** When modifying code for debugging, leverage `git` to track and revert changes (`git diff` to review injected debugs, `git stash`, or a temporary `WIP-debug` commit for a clean revert once the issue is solved).

## 6. Default `$PATH` Arsenal

You natively have access to: `nh`, `nix`, `statix`, `deadnix`, `pnpm`, `uv`, `rg`, `fd`, `jq`, `gh`, `git`, `direnv`.
