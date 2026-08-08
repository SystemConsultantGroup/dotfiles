# Local operating constraints

## NixOS

- System configuration is declarative in `~/dotfiles`. Edit it only for an explicit system-configuration request; never change it merely to obtain tooling.
- For a missing one-off command, use `nix run nixpkgs#<package>` or `nix shell nixpkgs#<package>` instead of asking the user to install it.
- Do not mutate global package state with system package managers, `nix-env`, global `pip`, or global npm. Add a permanent tool declaratively only when explicitly requested.

## Project ecosystems

- Respect the repository's existing package manager and lockfile. When none exists, use `uv` with a project virtual environment for Python or `pnpm` with a local lockfile for JavaScript.
- Never install project dependencies globally with `pip`, npm, or Yarn.

## Subagents

- For non-trivial work, proactively use the `pi-subagents` skill when scoped reconnaissance, research, implementation, or independent review would improve speed or confidence.
- Skip delegation when a quick read or direct command costs less than coordination.
- Keep the parent responsible for scope, synthesis, validation, and user communication.
- Prefer parallel read-only agents for independent work; allow only one writer per checkout or worktree.

## Working style

- Read relevant code and callers before editing; fix root causes at shared seams.
- Write self-explanatory code with descriptive names. Comment only to explain non-obvious reasons.
- Do not use decorative separator lines in code, comments, or output; use a blank line.
- Redirect long-running or chatty commands to a temporary file, then inspect the file. Pipe output only for fast commands with small results.
- Use authoritative URLs; search rather than guessing unfamiliar URLs.
- Run applicable focused validation before declaring completion.
- Act without asking when a safe default exists. Ask when a missing decision would materially change scope, architecture, or risk.
