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

## Local credentials

Direnv loads machine-local credentials from the gitignored `.envrc.local` after entering the flake environment. Create it with restrictive permissions:

```bash
install -m 600 /dev/null .envrc.local
```

For Cloudflare operations, define the account-scoped credentials without committing their values:

```bash
export CLOUDFLARE_API_TOKEN='...'
export CLOUDFLARE_ACCOUNT_ID='...'
```

After changing `.envrc` or `.envrc.local`, run `direnv allow`. Log out and back in after initially enabling direnv through the NixOS configuration.

## Apply

Review changes before activating them:

```bash
nh os switch .
```

For initial installation or recovery:

```bash
sudo nixos-rebuild switch --flake .#router
```
