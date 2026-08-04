# Agent Operating Context

## NixOS Context

- **Ephemeral / Missing Tools (Default):** Never fail or ask the user to install a missing command. Spawn it dynamically instead:
  - `nix run nixpkgs#<pkg>` (execute directly)
  - `nix shell nixpkgs#<pkg>` (interactive shell)
- **Permanent Tools:** Add explicitly to the flake (`environment.systemPackages`) and rebuild.

## Code Style

- Write strictly self-explanatory code with clear, descriptive variable names. Comment only when necessary to explain non-obvious "why" logic, never the "what".
- **No Decorative Separators:** Never write `=`, `-`, or any other character as decorative separator lines, banners, or borders, in comments, in code, or in output. If a visual break is genuinely needed, use a blank line.

## Sandboxed Ecosystems

- **Python:** Strictly `uv` with project venvs (`uv sync`, `uv pip`). No global `pip`.
- **JavaScript / Node:** Strictly `pnpm` with local lockfiles (`pnpm install`). No global `npm` or `yarn`.

## Bash Output Handling

- **Redirect long-running or chatty commands to a temp file; never pipe them.** Run `command > /tmp/cmd.log 2>&1`, then inspect `/tmp/cmd.log` with `read` or `rg` afterwards. Piping such output through `tail`, `head`, or `grep` loses the full record — the tool returns only the last 2000 lines / 50 KB, so early context and mid-stream errors vanish.
- **Pipe freely only when the command returns semi-instantly** and its output is small (`ls`, `git status`, a targeted `rg`). When in doubt, use the temp-file pattern: it costs one extra command and preserves everything.
