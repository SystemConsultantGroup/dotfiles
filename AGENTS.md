# Router configuration

Standalone NixOS configuration for the single `router` host.

## Structure

- `hosts/router/`: host composition and hardware configuration
- `modules/base/`: Nix, user, shell, Git, tools, and Pi
- `modules/router/`: interfaces, DHCP, forwarding, NAT, and firewall
- `modules/server/`: SSH, containers, service workarounds, and storage
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
