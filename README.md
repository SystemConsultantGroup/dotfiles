# SCG router

Declarative NixOS configuration for the SCG router and container host.

## Repository layout

- `hosts/router/` contains host-specific composition, hardware, networking, and storage.
- `modules/base/` contains shared operating-system and user configuration.
- `modules/router/` contains DHCP, DNS, nftables, and Cloudflare networking.
- `modules/server/` contains remote-administration services.

## Development

Enter the flake development environment to make the repository's validation tools available. Validate configuration changes with:

```bash
nix fmt
statix check .
deadnix .
nix flake check --no-build
nh os build .
```

A build evaluates and compiles the configuration without changing the running system.

## Local environment

Direnv loads machine-local variables from the gitignored `.envrc.local`. Create the file with restrictive permissions:

```bash
install -m 0600 /dev/null .envrc.local
```

Cloudflare tooling expects `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` in the environment. Keep all credentials out of tracked files and Nix expressions.

After changing `.envrc` or `.envrc.local`, authorize the environment again:

```bash
direnv allow
```

## Deployment

Review and build changes before activating them. Apply the validated configuration with:

```bash
nh os switch .
```

For installation or recovery, select the host explicitly:

```bash
sudo nixos-rebuild switch --flake .#router
```
