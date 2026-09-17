# Local operating constraints

## NixOS

- The system configuration is declarative in `~/dotfiles`.
- Change it only for an explicit system-configuration request.
- Use `nix run nixpkgs#<package>` or `nix shell nixpkgs#<package>` for a missing one-off tool.
- Never install global packages imperatively with a system package manager, `nix-env`, global npm, or global pip.
- Do not activate a new NixOS generation unless the user explicitly requests it.

## Router safety

- Treat routing, firewall, DHCP, network-interface, storage, and SSH changes as service-impacting.
- Preserve remote administration and established forwarding behavior unless a requested change requires otherwise.
- Build and validate changes before suggesting activation.
- Do not expose credentials, API keys, private keys, or session data in the repository.

## Working style

- Read relevant configuration and callers before editing.
- Prefer elegant solutions: keep structure coherent, remove duplication, and choose the simplest abstraction that makes the code easier to understand and maintain.
- Prefer small, direct changes over speculative abstraction.
- Use descriptive names and comment only non-obvious operational reasons.
- Do not discard unrecognized working-tree changes.
- Use authoritative documentation and search rather than guessing unfamiliar URLs.
