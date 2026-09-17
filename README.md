# SCG router

NixOS configuration for a headless router and container host.

## Services

- WAN/LAN routing with IPv4 and IPv6 forwarding
- Kea DHCP on the LAN
- nftables filtering and multi-address SNAT
- Cloudflare WARP
- OpenSSH and Podman
- Optional NTFS data mounts
- Pi coding agent

The host intentionally has no desktop environment or graphical applications.

## Layout

```text
hosts/router/     Host and hardware configuration
modules/base/     Nix, user, shell, tools, and Pi
modules/router/   Interfaces, DHCP, routing, NAT, and firewall
modules/server/   SSH, containers, workarounds, and storage
.pi/agent/        Pi settings
```

WAN is `enp0s25`; LAN is `enp5s0`. Public addresses declared in `modules/router/default.nix` are used both to configure the WAN interface and to build the SNAT pool.

## Validate

```bash
nix fmt
statix check .
deadnix .
nix flake check --no-build
nh os build .
```

A build does not modify the running system.

## Apply

Review service-impacting changes before activation, then run:

```bash
nh os switch .
```

For recovery or initial installation:

```bash
sudo nixos-rebuild switch --flake .#router
```

Pi is available as `pi`. Its tracked defaults live in `.pi/agent/`; runtime state remains writable through the overlay configured by `modules/base/pi.nix`. Authentication data, API keys, and session state must not be committed.
