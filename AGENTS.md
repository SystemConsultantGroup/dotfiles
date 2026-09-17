# SCG router configuration

This standalone repository defines the single headless NixOS host `router`. It is not synchronized with another dotfiles repository.

## Repository structure

- `configuration.nix`: host composition, boot, time zone, and state version
- `hardware-configuration.nix`: hardware-specific boot and filesystem facts
- `modules/base.nix`: Nix, user, shell, Git, SSH client, and administration tools
- `modules/networking.nix`: interfaces, addresses, DHCP, WARP, and link workarounds
- `modules/routing.nix`: forwarding and NAT
- `modules/firewall.nix`: packet-filter policy
- `modules/nftables.nix`: assembly of routing and firewall tables
- `modules/storage.nix`: optional data-disk mounts
- `modules/services.nix`: SSH server, Podman, and service workarounds
- `modules/pi.nix`: Pi installation and writable configuration overlay
- `.pi/agent/`: repository-managed Pi configuration

## Rules

- Use explicit `pkgs.` and `lib.` references. Do not use `with pkgs;` or `with lib;`.
- Keep routing and firewall policy in their respective modules.
- Keep machine-specific interface names, addresses, UUIDs, and workarounds explicit.
- Install permanent software declaratively. Use `nix run` or `nix shell` for temporary tools.
- Never use imperative global package installation.
- Do not discard or overwrite unrecognized working-tree changes.
- Do not activate a configuration unless the user explicitly requests it.
- Treat routing, firewall, DHCP, storage, and remote-access changes as service-impacting.

## Validation

For Nix changes, run all checks before committing:

```bash
nix fmt
statix check .
deadnix .
nix flake check --no-build
nh os build .
```

Warnings caused by repository code are errors. Diagnose failures, fix them, and rerun the checks.

## Git workflow

- Work on `master`.
- Use focused conventional commits (`feat:`, `fix:`, `refactor:`, or `chore:`).
- Push successful changes to `origin`.
- The `pre-headless-refactor` tag preserves the former desktop/fork configuration.
