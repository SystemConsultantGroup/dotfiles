# SCG router

Declarative NixOS configuration for the SCG router and container host.

## Repository layout

- `hosts/router/` contains host-specific composition, hardware, networking, and storage. Operator values such as addresses and WARP instances live in `hosts/router/site.toml`.
- `modules/base/` contains shared operating-system and user configuration.
- `modules/router/` contains interfaces, DHCP, DNS, nftables, and WARP networking.
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

## WARP instances

[Waywarp](https://github.com/apersomany/waywarp) runs each WARP client as a bridge instance:

| Instance | Link | Role |
| --- | --- | --- |
| `mesh` | `waywarp0` | Mesh node `scg-skku-router`, joined with the office LAN |
| `mesh-jp` | `waywarp1` | Mesh node `scg-skku-router-jp`, whose clients exit through `warp-jp` |
| `warp-jp` | `waywarp2` | WARP client that exits in Osaka, Japan (KIX), bootstrapped through Azure relays |

Mesh nodes use registrations enrolled with the Cloudflare client. Import each one before its unit starts; the unit is skipped until the registration exists:

```bash
sudo waywarp import 0 --from /path/to/scg-skku-router-state
sudo waywarp import 1 --from /path/to/scg-skku-router-jp-state
```

Imported registrations live in `/var/lib/waywarp/{0,1}/registration`; the old container state has been removed.

Waywarp's default `nat = "auto"` follows the live connector configuration. The `mesh` node advertises `10.0.0.0/16` with connector NAT disabled, so LAN-started connections keep their real LAN source addresses. Sources outside advertised routes are SNATed only to the device's assigned WARP addresses; `warp-jp` translates all sources. Dashboard edits update namespace NAT rules automatically, while host routes and firewall remain declarative. Existing connections retain their conntrack mappings and may need reconnecting after a route removal or address change.

`warp-jp` bootstraps through Mudfish's Osaka Azure nodes (`mudfish:city=osaka+provider=azure`) and requires `geo4=JP/Osaka+edge=KIX`. Waywarp paces Mudfish authentication across instances to avoid login throttling. The service starts once `/var/lib/secrets/waywarp-mudfish.env` provides `WAYWARP_MUDFISH_USERNAME` and `WAYWARP_MUDFISH_PASSWORD`. Create it with mode `0600`.

### Japanese hostname routing

Cloudflare-side hostname routes select which traffic reaches `mesh-jp`; the router then forwards it through `warp-jp`. Cloudflare returns synthetic IPv4 **and IPv6** addresses for these names. Both families therefore need working host forwarding, Japan policy routes, and return routes to Mesh clients. The IPv6 device range is Cloudflare's fixed `2606:4700:cf1:1000::/64` ([reserved IP ranges](https://developers.cloudflare.com/cloudflare-one/networks/routes/reserved-ips/)).

Table `201` carries the Japanese default and Mesh return routes for both families. A blackhole default prevents fallback to the WAN when the Japan exit is unavailable. IPv6 forwarding is allowed only between the Japanese links; ordinary LAN/WAN and LAN/Mesh forwarding stays IPv4-only. The main table also has a Mesh IPv6 return route so router-generated ICMP errors can reach clients.

When investigating a routed hostname, compare `curl -4` and `curl -6` from an enrolled client using Cloudflare DNS. Requests sent straight through `waywarp2` test only the exit, not Cloudflare's hostname-routing path. An IPv4-only host can make native apps stall on IPv6 while browsers fall back to IPv4, even when video and thumbnails on other hostnames work.

## Deployment

Review and build changes before activating them. Apply the validated configuration with:

```bash
nh os switch .
```

For installation or recovery, select the host explicitly:

```bash
sudo nixos-rebuild switch --flake .#router
```
