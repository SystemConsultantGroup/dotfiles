# SCG router

Declarative NixOS configuration for the SCG router and container host.

## Repository layout

- `hosts/router/` contains host-specific composition, hardware, networking, and storage. Operator values such as addresses and WARP instances live in `hosts/router/site.toml`.
- `modules/base/` contains shared operating-system and user configuration.
- `modules/router/` contains interfaces, DHCP, DNS, nftables, WARP networking, and service composition in `default.nix`.
- `modules/router/fe/` contains the React/shadcn/Vite application and its Nix package.
- `modules/router/be/` contains the Rust application, SQLite migrations, and its Nix package.
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

A build evaluates and compiles the configuration without changing the running system. The development shell also provides Rust, Node.js, and pnpm. Build the application packages independently with `nix build .#fe .#be`.

For application iteration:

```bash
pnpm --dir modules/router/fe install --frozen-lockfile
pnpm --dir modules/router/fe build
pnpm --dir modules/router/fe lint
cargo fmt --manifest-path modules/router/be/Cargo.toml --check
cargo clippy --manifest-path modules/router/be/Cargo.toml -- -D warnings
```

Use package managers to add or update dependencies; keep their generated lockfiles committed.

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

## WARP instances

[Waywarp](https://github.com/apersomany/waywarp) runs each WARP client as a bridge instance:

| Instance | Link | Role |
| --- | --- | --- |
| `mesh` | `waywarp0` | Mesh node `scg-skku-router`, joined with the office LAN |
| `mesh-yt` | `waywarp1` | Selective-service Mesh ingress; defaults to `warp-jp` and retains the imported `scg-skku-router-jp` registration |
| `warp-jp` | `waywarp2` | WARP client that exits in Osaka, Japan (KIX), bootstrapped through Azure relays |

Mesh nodes use registrations enrolled with the Cloudflare client. Import each one before its unit starts; the unit is skipped until the registration exists:

```bash
sudo waywarp import 0 --from /path/to/scg-skku-router-state
sudo waywarp import 1 --from /path/to/scg-skku-router-jp-state
```

Imported registrations live in `/var/lib/waywarp/{0,1}/registration`; the old container state has been removed.

Waywarp's default `nat = "auto"` follows the live connector configuration. The `mesh` node advertises `10.0.0.0/16` with connector NAT disabled, so LAN-started connections keep their real LAN source addresses. Sources outside advertised routes are SNATed only to the device's assigned WARP addresses; `warp-jp` translates all sources. Dashboard edits update namespace NAT rules automatically, while host routes and firewall remain declarative. Existing connections retain their conntrack mappings and may need reconnecting after a route removal or address change.

`warp-jp` bootstraps through Mudfish's Osaka Azure nodes (`mudfish:city=osaka+provider=azure`) and requires `geo4=JP/Osaka+edge=KIX`. Waywarp paces Mudfish authentication across instances to avoid login throttling. The service starts once `/var/lib/secrets/waywarp-mudfish.env` provides `WAYWARP_MUDFISH_USERNAME` and `WAYWARP_MUDFISH_PASSWORD`. Create it with mode `0600`.

### IPv4 routing

Cloudflare-side routes decide whether traffic reaches `mesh` or `mesh-yt`. The router independently selects an Internet exit for each `(ingress interface, source IPv4)` pair. Office and ordinary Mesh traffic default to SKKU; `mesh-yt` defaults to WARP Japan. The application cannot affect traffic that Cloudflare does not deliver to the router.

Upstream tables `200` (SKKU) and `201` (WARP Japan) have blackhole defaults, preventing fallback when an exit is unavailable. Return tables `210`, `211`, and `212` preserve the office, Mesh, and mesh-yt reply paths. Connection marks retain the selected exit for existing connections; changes apply to new connections. Internal office/Mesh destinations bypass Internet-exit selection. IDs and tables are declared in `hosts/router/network.nix`; ingress defaults live in `site.toml`.

Nix owns the fixed firewall, NAT, routing rules, and fail-closed defaults. Networkd installs physical-interface routes; Waywarp installs bridge routes when each instance is ready. The be owns only the `inet router_be` classification table, which survives Nix-owned table reloads. Internet-exit and return marks occupy `0x00ff0000` and `0xff000000`; the low 16 bits are preserved. Do not reuse these mark fields or globally flush nftables.

Downstream forwarding is IPv4-only. Router DNS filters AAAA answers, but WARP clients using Cloudflare DNS may still receive synthetic IPv6 answers. IPv6 bridge neighbor discovery and a Mesh return route remain solely for internal operation and router-generated errors, not IPv6 Internet forwarding. Check IPv4 access and prompt rejection/fallback of IPv6 from enrolled clients before activation; querying through `waywarp2` alone does not exercise Cloudflare hostname routing.

## Device self-service

The canonical URL is `https://router.scg.sh`. Its public Cloudflare record is a DNS-only A record for `10.0.0.1`, with no AAAA record or Cloudflare proxy. Clients still need office or Mesh routing to that private address. Router DNS also serves the same address locally, with a narrowly scoped rebinding exception.

The fe is a static application served by `router-be`, which terminates HTTPS directly. The request's actual source IPv4 is its identity and authorization: no accounts, cookies, sessions, or trusted forwarding headers. Exact hostname checks, same-origin JSON mutations, browser-origin protections, and downstream-only access protect the API. This model assumes downstream source-address integrity; TLS does not prevent source-IP impersonation on a compromised local network.

The application offers internal DNS naming under `home.arpa` and a named upstream selector for each applicable ingress. Office addresses get one selector; Mesh addresses get base and mesh-yt selectors. There is no device merging across addresses. Firewall controls and HTTP/Minecraft publication are not implemented.

`router-be-controller` serializes SQLite updates and reconciles nftables and a dnsmasq hosts directory. It has `CAP_NET_ADMIN`; the HTTPS service has only `CAP_NET_BIND_SERVICE`. Their Unix socket is private to the be group, while certificate access uses a separate TLS group. The HTTPS service remains available across controller restarts and reports temporary API failures until the socket returns.

Runtime state lives in `/var/lib/router-be/`: `state.sqlite` holds assignments and settings, `dns/hosts` holds generated DNS records, and `leases/` preserves DHCP-reported names and new-assignment markers captured by the existing neighbor hook. Dnsmasq's independent DHCP-name registration is disabled so the controller can enforce unique names, reserved names, and explicit overrides. Valid reported names are automatic defaults; collisions receive an address-derived suffix. Back up the state directory separately from the repository.

DHCP assignments are reconciled every five seconds. Mesh registrations and their `virtual_ipv4` addresses are fetched through the paginated Cloudflare registrations API approximately every minute. Confirmed expiry, removal, or reassignment clears associated preferences and DNS ownership. Inventory failures retain the last known state and do not revoke source-IP authorization. Static or otherwise untracked sources can use self-service immediately; their settings persist until an authoritative assignment is learned and subsequently ends. Being offline is not evidence of assignment expiry. If the controller is down, the last applied forwarding policy remains, but assignment cleanup pauses until recovery.

### TLS and Cloudflare credentials

The existing `/home/scg/dotfiles/.envrc.local` is the credential source configured by `be.environmentFile` in `site.toml`. Keep it untracked, operator-controlled, and mode `0600`; it is a trusted shell file exporting `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. No second persistent credential file is required. The token needs WARP-registration read access for the intended account, plus **Zone / Zone / Read** and **Zone / DNS / Edit** scoped to `scg.sh`. Account-level DNS Settings permissions are not a substitute for zone DNS-record permissions. Never interpolate credential values into Nix expressions.

PID 1 uses `LoadCredential` to provide a separate, protected runtime-memory copy to the controller and ACME renewal job before their home-directory sandboxes are applied. A shared loader sources that credential with shell tracing and source output disabled, then exports the two variables in process memory. Secret values never enter Nix expressions, the Nix store, generated unit files, or command-line arguments. The HTTPS-facing service receives no Cloudflare credentials. Credential consumers disable core dumps. An empty, non-secret fallback lets the controller run without inventory credentials if the source is absent; ACME additionally checks for the source file.

NixOS ACME uses DNS-01; no public inbound HTTP/HTTPS listener is required. Its wrapper maps the loaded token to lego's Cloudflare provider variable only in memory. The HTTPS service never serves ACME's preliminary self-signed certificate: it waits for a successful issuance marker, and issuance/renewal starts or restarts it with the trusted certificate. Missing credentials do not stop forwarding or source-IP self-service when a previously issued certificate is available, but Mesh cleanup and new certificate issuance require them. Changes to `.envrc.local` are picked up when a consumer next starts: restart the controller after rotation; each ACME invocation loads the current source.

## Deployment

Review and build changes before activating them. Apply the validated configuration with:

```bash
nh os switch .
```

For installation or recovery, select the host explicitly:

```bash
sudo nixos-rebuild switch --flake .#router
```
