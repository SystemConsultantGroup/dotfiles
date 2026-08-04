# SYSTEM_ENV: NixOS (Flake/Declarative)

**Core Directive:** You operate on an immutable, declarative NixOS system. Ad-hoc global mutations are strictly forbidden. System conventions supersede project-level `AGENTS.md` rules.

## 1. Context & Identity

- **User:** `aperso` (`/home/aperso`)
- **System Flake:** `~/dotfiles`
- **Agent Config:** `~/.pi/agent/`

## 2. Code Style

- Write strictly self-explanatory code with clear, descriptive variable names. Comment only when necessary to explain non-obvious "why" logic, never the "what".
- **No Decorative Separators:** Never write `=`, `-`, or any other character as decorative separator lines, banners, or borders, in comments, in code, or in output. If a visual break is genuinely needed, use a blank line.

## 3. Package Management

**FORBIDDEN:** `apt`, `dnf`, `brew`, `pacman`, `pip install` (global), `npm i -g`, `nix-env`.

- **Ephemeral / Missing Tools (Default):** Never fail or ask the user to install a missing command. Spawn it dynamically instead:
  - `nix run nixpkgs#<pkg>` (execute directly)
  - `nix shell nixpkgs#<pkg>` (interactive shell)
- **Permanent Tools:** Add explicitly to the flake (`environment.systemPackages`) and rebuild.

## 4. Sandboxed Ecosystems

- **Python:** Strictly `uv` with project venvs (`uv sync`, `uv pip`). No global `pip`.
- **JavaScript / Node:** Strictly `pnpm` with local lockfiles (`pnpm install`). No global `npm` or `yarn`.

## 5. Bash Output Handling

- **Redirect long-running or chatty commands to a temp file; never pipe them.** Run `command > /tmp/cmd.log 2>&1`, then inspect `/tmp/cmd.log` with `read` or `rg` afterwards. Piping such output through `tail`, `head`, or `grep` loses the full record — the tool returns only the last 2000 lines / 50 KB, so early context and mid-stream errors vanish.
- **Pipe freely only when the command returns semi-instantly** and its output is small (`ls`, `git status`, a targeted `rg`). When in doubt, use the temp-file pattern: it costs one extra command and preserves everything.

## 6. Analysis & Debugging Strategy

- **Dynamic > Static:** Do not fall into long chains of static analysis unless the code takes forever to execute. Dynamic analysis is key to quick resolution.
- **Get Your Hands Dirty:** Do not fear attaching debuggers or injecting aggressive `print`/`console.log`/`debug` statements into the code.
- **Cleanup via Git:** When modifying code for debugging, leverage `git` to track and revert changes (`git diff` to review injected debugs, `git stash`, or a temporary `WIP-debug` commit for a clean revert once the issue is solved).

## 7. Default `$PATH` Arsenal

You natively have access to: `nh`, `nix`, `statix`, `deadnix`, `pnpm`, `uv`, `rg`, `fd`, `jq`, `gh`, `git`, `direnv`.
