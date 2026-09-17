# SCG router configuration

This standalone repository defines the single headless NixOS host `router`. It is not synchronized with another dotfiles repository.

## Repository structure

- `hosts/router/configuration.nix`: host composition, boot, time zone, and state version
- `hosts/router/hardware-configuration.nix`: hardware-specific boot and filesystem facts
- `modules/base/`: shared Nix, user, shell, Git, tools, and Pi configuration
- `modules/router/`: interfaces, DHCP, forwarding, NAT, and packet filtering
- `modules/server/`: SSH, containers, service workarounds, and data disks
- `.pi/agent/`: repository-managed Pi configuration

## Rules

- Use explicit `pkgs.` and `lib.` references. Do not use `with pkgs;` or `with lib;`.
- Keep host-specific composition under `hosts/router/`.
- Keep reusable concerns under `modules/{base,router,server}/`.
- Keep routing and firewall policy in their respective files.
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
