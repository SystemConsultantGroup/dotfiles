# SCG router

NixOS configuration for a headless router and container host.

## Validate

```bash
nix fmt
statix check .
deadnix .
nix flake check --no-build
nh os build .
```

Building does not change the running system.

## Apply

Review changes before activating them:

```bash
nh os switch .
```

For initial installation or recovery:

```bash
sudo nixos-rebuild switch --flake .#router
```
