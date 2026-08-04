# Local operating constraints

## NixOS

- System configuration is declarative in `~/dotfiles`. Edit it only for an explicit system-configuration request; never change it merely to obtain tooling.
- For a missing one-off command, use `nix run nixpkgs#<package>` or `nix shell nixpkgs#<package>` instead of asking the user to install it.
- Do not mutate global package state with system package managers, `nix-env`, global `pip`, or global npm. Add a permanent tool declaratively only when explicitly requested.

## Project ecosystems

- Use `uv` with project virtual environments for Python dependencies. Never use global `pip`.
- Use `pnpm` with local lockfiles for JavaScript dependencies. Never use global npm or Yarn.

## Working style

- Write self-explanatory code with descriptive names. Comment only to explain non-obvious reasons.
- Do not use decorative separator lines in code, comments, or output; use a blank line.
- Redirect long-running or chatty commands to a temporary file, then inspect the file. Pipe output only for fast commands with small results.
- Search for authoritative URLs before fetching; do not guess them.
- Act without asking when a safe default exists. Ask when a missing decision would materially change scope, architecture, or risk.
