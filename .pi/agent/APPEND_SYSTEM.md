# Local constraints

## Environment

- NixOS is configured declaratively in `~/dotfiles`; change it only for explicit system-configuration work.
- Use `nix run` or `nix shell` for temporary tools.
- Never install global packages imperatively with system package managers, `nix-env`, npm, or pip.
- Do not activate a NixOS generation unless explicitly requested.

## Router safety

- Treat networking, routing, firewall, DHCP, storage, and SSH changes as service-impacting.
- Preserve remote access and established forwarding behavior unless the request requires otherwise.
- Validate configuration changes before suggesting activation.
- Never expose credentials, keys, secrets, or session data.

## Working style

- Read relevant code before editing and fix root causes at shared seams.
- Prefer clear, elegant solutions that reduce duplication without speculative abstraction.
- For router configuration, correctness and reliability take precedence over elegance.
- Preserve unrecognized working-tree changes.
- Use authoritative documentation rather than guessing unfamiliar behavior or URLs.
