# SYSTEM_ENV: NixOS (Flake/Declarative)

**Core Directive:** You operate on an immutable, declarative NixOS 26.11 system. Ad-hoc global mutations are strictly forbidden. System conventions supersede project-level `AGENTS.md` rules.

## 1. Context & Identity

* **User:** `aperso` (`/home/aperso`)
* **System Flake:** `~/dotfiles`
* **Agent Config:** `~/.pi/agent/`
* **Code Style:** Write strictly self-explanatory code. Use clear, descriptive variable names. Comment *only* when absolutely necessary to explain non-obvious "why" logic, never the "what."
* **No Decorative Separators:** Never write `=` or `-` (or any other character) as decorative separator lines, banners, or borders — in comments, in code, or in any output. LLMs cannot align them reliably, and they add zero signal. If a visual break is genuinely needed, use a blank line.

## 2. The Golden Rule: Package Management

> **FORBIDDEN:** `apt`, `dnf`, `brew`, `pacman`, `pip install` (global), `npm i -g`, `nix-env`.

* **Ephemeral / Missing Tools (Default):** Never fail or ask the user to install a missing command. Always spawn it dynamically:
* `nix run nixpkgs#<pkg>` (execute directly)
* `nix shell nixpkgs#<pkg>` (interactive shell)

* **Permanent Tools:** Add explicitly to flake (`users.users.<name>.packages` or `environment.systemPackages`) and rebuild.

## 3. Sandboxed Ecosystems

* **Python:** Strictly use `uv` with project venvs (`uv sync`, `uv pip`). No global `pip`.
* **JavaScript / Node:** Strictly use `pnpm` with local lockfiles (`pnpm install`). No global `npm` or `yarn`.

## 4. Execution & Bash Etiquette

* **NO PIPED LOGGING:** **NEVER EVER** use piped `tail`, `head`, or `grep` directly on bash calls unless they are expected to return semi-instantly.
* **Temp Files First:** If a command takes time to run, redirect its output to `/tmp/` (e.g., `command > /tmp/cmd_output.log 2>&1`), then inspect the file. The only exception is if the output is guaranteed to be 100GB+.

## 5. Analysis & Debugging Strategy

* **Dynamic > Static:** Do not fall into long chains of static analysis unless the code takes forever to execute. Dynamic analysis is key to quick resolution.
* **Get Your Hands Dirty:** Do not fear attaching debuggers or injecting aggressive `print`/`console.log`/`debug` statements into the code.
* **Cleanup via Git:** When modifying code for debugging, leverage `git` to track and revert your changes. (e.g., Use `git diff` to review your injected debugs, `git stash`, or make a temporary `WIP-debug` commit so you can easily cleanly revert the state once the issue is solved).

## 6. Default `$PATH` Arsenal

You natively have access to: `nh`, `nix`, `statix`, `deadnix`, `pnpm`, `uv`, `rg`, `fd`, `fzf`, `jq`, `bat`, `gh`, `git`, `direnv`.
