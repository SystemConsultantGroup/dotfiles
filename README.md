# SCG router

Declarative NixOS configuration for a single headless router and container host.

## System role

The host provides:

- WAN/LAN routing with IPv4 and IPv6 forwarding
- Kea DHCP on the LAN
- nftables filtering and multi-address SNAT
- Cloudflare WARP
- OpenSSH administration
- Podman for hosted services
- Optional NTFS data-disk mounts
- Pi as the on-host configuration agent

It intentionally has no desktop environment, display manager, graphical applications, printing stack, or proprietary GPU driver.

## Repository layout

| Path | Responsibility |
| --- | --- |
| `configuration.nix` | Host composition, bootloader, kernel, time zone, and state version |
| `hardware-configuration.nix` | Hardware-specific boot modules and system filesystems |
| `modules/base.nix` | Nix settings, administrator account, shell, Git, and CLI tools |
| `modules/networking.nix` | Interfaces, addresses, DHCP, WARP, and NIC workarounds |
| `modules/routing.nix` | Forwarding sysctls and multi-address SNAT |
| `modules/firewall.nix` | Forwarded-traffic policy |
| `modules/nftables.nix` | Combined nftables ruleset assembly |
| `modules/storage.nix` | `/mnt/storage` and `/mnt/download` |
| `modules/services.nix` | OpenSSH, Podman, and ARP-cache workaround |
| `modules/pi.nix` | Pi executable and writable configuration overlay |
| `.pi/agent/` | Pi settings and web-search configuration |

The WAN interface is `enp0s25`; the LAN interface is `enp5s0`.

## Validate changes

```bash
nix fmt
statix check .
deadnix .
nix flake check --no-build
nh os build .
```

A build does not modify the running system.

## Apply changes

Review routing, firewall, DHCP, and SSH changes before activation. Apply a validated configuration with:

```bash
nh os switch .
```

For recovery or a fresh installation:

```bash
sudo nixos-rebuild switch --flake .#router
```

## Pi configuration

Pi is available as `pi`. Repository defaults live under `.pi/agent/`; `modules/pi.nix` overlays that directory at `~/.pi` while keeping runtime state writable.

Do not commit authentication data, session history, trust state, or API secrets. These paths are excluded by `.gitignore`.

## Recovery

The Git tag `pre-headless-refactor` points to the final configuration before the repository became a standalone headless router configuration.
