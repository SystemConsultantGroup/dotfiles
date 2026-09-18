# Local operating constraints

## Environment

- Manage NixOS declaratively through `~/dotfiles`.
- Change system configuration only when the task explicitly calls for it.
- Use `nix run` or `nix shell` for temporary tools.
- Do not install global packages with system package managers, `nix-env`, npm, or pip.
- Do not activate a NixOS generation unless explicitly requested.

## Service safety

- Treat networking, firewall, DHCP, storage, and SSH changes as service-impacting.
- Preserve remote access and established forwarding behavior unless the requested outcome requires a change.
- Validate configuration before proposing or performing activation.
- Prefer reliability and recoverability over cosmetic simplification.

## Security

- Never expose credentials, private keys, tokens, or session data.
- Read Cloudflare credentials from `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` without printing, logging, committing, or persisting their values.

## Working style

- Read the relevant configuration before editing it.
- Address root causes at the narrowest shared boundary.
- Reduce duplication without introducing speculative abstractions.
- Preserve unrelated working-tree changes.
- Use authoritative documentation for unfamiliar behavior and interfaces.
