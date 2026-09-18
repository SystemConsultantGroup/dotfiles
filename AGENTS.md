# Router configuration

Standalone NixOS configuration for the single `router` host.

## Structure

- `hosts/router/`: host composition, network topology, hardware, and storage
- `modules/base/`: Nix, user, shell, Git, tools, and Pi
- `modules/router/`: interfaces, DHCP, forwarding, firewall, and Cloudflare networking
- `modules/server/`: remote access
- `.pi/agent/`: repository-managed Pi configuration

Keep host-specific composition in `hosts/router/` and reusable concerns in the appropriate module. Keep routing and firewall policy in separate files.

## Rules

- Prefer clear, coherent, non-duplicative configuration.
- Correctness, reliability, recoverability, and operational clarity take precedence over elegance.
- Treat networking, routing, firewall, DHCP, storage, and SSH changes as service-impacting.
- Use explicit `pkgs.` and `lib.` references; never use `with pkgs;` or `with lib;`.
- Install permanent software declaratively; use `nix run` or `nix shell` for temporary tools.
- Preserve unrecognized working-tree changes.
- Do not activate a configuration unless explicitly requested.
- Use `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` from the environment for Cloudflare operations; never print, log, commit, or persist their values.

## Local credentials

Store machine-local environment variables in the gitignored `.envrc.local`. Direnv loads this file after the flake environment. Keep it mode `0600` and never place secrets in tracked files or Nix expressions.

## Validation

For Nix changes, run:

```bash
nix fmt
statix check .
deadnix .
nix flake check --no-build
nh os build .
```

Treat warnings caused by repository code as failures. For documentation-only changes, run `git diff --check`.

## Delivery

Work on `master`, use focused conventional commits, and push successful changes to `origin`. The `pre-headless-refactor` tag preserves the former desktop configuration.
