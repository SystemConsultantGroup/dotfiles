# SCG router

Declarative NixOS configuration for the SCG router and container host.

## Repository layout

- `hosts/router/`: host composition, hardware, networking, and storage. Operator values live in `hosts/router/site.toml`.
- `modules/base/`: shared system, users, shells, and tooling.
- `modules/router/`: interfaces, DHCP, DNS, firewall, NAT, routing, and WARP.
- `modules/router/fe/` and `modules/router/be/`: self-service frontend and backend, including their Nix packages.
- `modules/server/`: remote administration.

## Development

Enter the development environment with `nix develop`. Validate Nix changes with:

```bash
nix fmt
statix check .
deadnix .
nix flake check --no-build
nh os build .
```

Build application packages with `nix build .#fe .#be`. For application iteration:

```bash
pnpm --dir modules/router/fe install --frozen-lockfile
pnpm --dir modules/router/fe build
pnpm --dir modules/router/fe lint
cargo fmt --manifest-path modules/router/be/Cargo.toml --check
cargo clippy --manifest-path modules/router/be/Cargo.toml -- -D warnings
```

Use package managers to update dependencies and commit their lockfiles. Builds do not activate the system; deploy through the private wrapper below.

## Local environment

Direnv loads machine-local variables from the gitignored `.envrc.local`. Keep it untracked and mode `0600`; never put credentials in Nix expressions or tracked files. Run `direnv allow` after changing the direnv configuration.

Cloudflare tooling expects `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. The existing `.envrc.local` is also the runtime credential source for the controller and ACME through systemd `LoadCredential`. The token needs WARP-registration read access for the account, plus **Zone / Zone / Read** and **Zone / DNS / Edit** scoped to `scg.sh`. Restart the controller after rotating credentials; ACME reloads them on its next run.

## WARP instances

[Waywarp](https://github.com/apersomany/waywarp) runs each WARP client as a bridge instance:

| Instance | Link | Role |
| --- | --- | --- |
| `mesh` | `waywarp0` | Mesh node `scg-skku-router`, connected to the office LAN; also the standard WARP upstream |
| `mesh-yt` | `waywarp1` | YouTube Mesh ingress; defaults to WARP Japan and retains its imported `scg-skku-router-jp` registration |
| `warp-jp` | `waywarp2` | WARP Japan, constrained to Osaka/KIX and bootstrapped through Mudfish Azure relays |

Import the enrolled Mesh registrations before starting their units:

```bash
sudo waywarp import 0 --from /path/to/scg-skku-router-state
sudo waywarp import 1 --from /path/to/scg-skku-router-jp-state
```

Registrations live in `/var/lib/waywarp/{0,1}/registration`; imported instances are skipped until their registration exists. WARP Japan additionally requires `/var/lib/secrets/waywarp-mudfish.env`, mode `0600`, containing `WAYWARP_MUDFISH_USERNAME` and `WAYWARP_MUDFISH_PASSWORD`.

Waywarp's `nat = "auto"` follows the connector configuration. With connector NAT disabled, sources within the advertised office route keep their LAN addresses; other sources are translated to the device's assigned WARP addresses. Dashboard changes update namespace NAT rules automatically. Existing connections may need reconnecting after route or address changes.

### Routing

Downstream forwarding is IPv4-only. Cloudflare routes determine whether traffic reaches the Base or YouTube ingress; router policy then selects its upstream. Office and Base default to SKKU; YouTube defaults to WARP Japan. Standard WARP reuses `mesh`, without another instance or registration.

Upstream tables `200` (SKKU), `201` (WARP Japan), and `202` (WARP) have blackhole defaults to prevent fallback. Return tables `210`, `211`, and `212` preserve Office, Base, and YouTube reply paths. Internal destinations bypass upstream selection, and preference changes apply to new connections. IDs and tables live in `hosts/router/network.nix`; defaults live in `site.toml`.

Nix owns the fixed firewall, NAT, and routing policy; the backend owns only `inet router_be`. Routing reserves conntrack-label bits `111..127` and packet-mark fields `0x00ff0000` and `0xff000000`, leaving connection marks untouched for Laminar. Do not reuse these fields or globally flush nftables.

IPv6 link-local and Mesh error-return plumbing remain for Waywarp internals, not downstream Internet forwarding. Router DNS filters AAAA records, but Cloudflare clients may still receive synthetic IPv6 answers; verify IPv4 connectivity and IPv6 rejection/fallback from enrolled clients.

## Self-service portal

The self-service portal is available at [router.scg.sh](https://router.scg.sh) from the office or Mesh network.

## Deployment

Deploy through `~/dotfiles-private`, which extends this configuration with Laminar and its tunnel. NH defaults to that wrapper; explicit paths also work from older shells. Activation requires explicit operator approval; `nh os build .` above validates the public configuration only and must not be followed by a switch of the public flake.

Keep its public input on `git+file:///home/scg/dotfiles`. Commit public changes, update the wrapper's pin, and build before activating:

```bash
nix flake update dotfiles --flake ~/dotfiles-private
nh os build ~/dotfiles-private
# Review the build diff before switching.
nh os switch ~/dotfiles-private
```

Do not use `path:/home/scg/dotfiles` for that input: directory snapshots can copy gitignored credentials and build outputs into the world-readable Nix store. Keep secrets outside the private wrapper's source tree too. Switching the public flake directly omits private services.

For installation or recovery, select the wrapper and host explicitly:

```bash
sudo nixos-rebuild switch --flake /home/scg/dotfiles-private#router
```
