# Headless NixOS router configuration

This repository is the standalone configuration for the `router` host. It is not synchronized with another dotfiles repository.

## Conventions

- Use explicit `pkgs.` and `lib.` references; do not use `with pkgs;` or `with lib;`.
- Keep host composition in `configuration.nix` and hardware facts in `hardware-configuration.nix`.
- Keep network interfaces and DHCP in `modules/networking.nix`.
- Keep forwarding and NAT in `modules/routing.nix`.
- Keep packet-filter policy in `modules/firewall.nix`.
- Keep mounted data disks in `modules/storage.nix`.
- Keep daemons and containers in `modules/services.nix`.
- Install permanent tools declaratively. Use `nix run` or `nix shell` for one-off tools.
- Do not discard unrecognized working-tree changes.

## Validation

Before every commit, run:

```bash
statix check .
deadnix .
nix fmt
nh os build .
```

Warnings from repository code are errors. Fix failures and retry before reporting them.

## Git workflow

- Work directly on `master` after the initial refactor is complete.
- Use conventional commit prefixes such as `feat:`, `fix:`, `refactor:`, and `chore:`.
- Make small, focused commits and push successful changes to `origin`.
