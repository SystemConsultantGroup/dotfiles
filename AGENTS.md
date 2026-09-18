# Repository guidelines

This repository defines the NixOS configuration for the `router` host.

## Layout

- `hosts/router/`: host composition, hardware, network topology, and storage
- `modules/base/`: shared system, user, shell, Git, tooling, and Pi configuration
- `modules/router/`: router services, packet processing, and Cloudflare networking
- `modules/server/`: remote administration
- `.pi/agent/`: repository-managed Pi instructions

Keep machine-specific values in `hosts/router/` and reusable behavior in `modules/`. Keep NAT and routing concerns separate from firewall policy so that service-impacting changes remain easy to review.

## Configuration standards

- Prefer clear, coherent configuration over abstraction for its own sake.
- Prioritize correctness, reliability, recoverability, and operational clarity.
- Use explicit `pkgs.` and `lib.` references; do not use `with pkgs;` or `with lib;`.
- Install persistent software declaratively. Use `nix run` or `nix shell` for temporary tools.
- Preserve working-tree changes that are unrelated to the task.
- Treat networking, firewall, DHCP, storage, and SSH changes as service-impacting.
- Preserve remote access and established forwarding behavior unless a requested change requires otherwise.
- Do not activate a NixOS generation unless explicitly requested.

## Secrets and local state

Keep machine-local environment variables in the gitignored `.envrc.local`. The file must remain untracked and should have mode `0600`. Never place credentials, private keys, tokens, or session data in tracked files or Nix expressions.

Cloudflare tooling reads `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` from the environment. Never print, log, commit, or persist their values.

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

Work on `master`. Use focused conventional commits and push successful changes to `origin`.
