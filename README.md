# SCG router

Standalone NixOS configuration for a headless router and container host.

## Layout

- `configuration.nix` — host composition, bootloader, kernel, and NixOS state version
- `hardware-configuration.nix` — generated hardware and filesystem facts
- `modules/base.nix` — user, shell, Git, Nix, and administrative tools
- `modules/networking.nix` — interfaces, addresses, DHCP, and link workarounds
- `modules/routing.nix` — packet forwarding and multi-address SNAT
- `modules/firewall.nix` — forwarded-traffic policy
- `modules/nftables.nix` — combines routing and firewall tables into one ruleset
- `modules/storage.nix` — persistent NTFS data-disk mounts
- `modules/services.nix` — OpenSSH, Podman, and the DHCP-client ARP workaround
- `modules/pi.nix` — Pi coding agent package and writable configuration overlay
- `.pi/agent/` — repository-managed Pi configuration

## Build and apply

Validate without activating:

```bash
nh os build .
```

Apply the configuration:

```bash
nh os switch .
```

For initial recovery from a NixOS installer:

```bash
sudo nixos-rebuild switch --flake .#router
```

## Development checks

```bash
statix check .
deadnix .
nix fmt
nh os build .
```

## Operational notes

- WAN is `enp0s25`; LAN is `enp5s0`.
- Kea provides DHCP on the LAN.
- nftables implements SNAT and a default-deny forwarding policy.
- `/mnt/storage` and `/mnt/download` are optional NTFS mounts and will not block boot when absent.
- Pi is the primary on-host configuration agent.
