# dotfiles

**Donghyun Shin's NixOS flake** — declarative Hyprland desktop/laptop config with
AMD NPU acceleration, Korean input, and a modular module system.

## Quick start

```bash
git clone https://github.com/apersomany/dotfiles ~/dotfiles && cd ~/dotfiles
sudo nh os switch . --hostname workstation   # or --hostname laptop
```

**Prerequisites:** NixOS with `nix-command` + `flakes`; generate
`hosts/<host>/hardware-configuration.nix` via `nixos-generate-config`.

## Hosts

| Host | Role | Highlights |
|------|------|------------|
| `workstation` | Desktop | AMD Ryzen AI (NPU), ROCm, image gen |
| `laptop` | Laptop | ASUS ROG, accelerometer, `asusd` |

## Modules

```
modules/
├── base/          # Nix daemon, networking, firewall, user env, system pkgs
├── client/        # Hyprland (via UWSM), greetd, apps, theming, fonts, kime
└── server/        # Headless: SSH, Podman, GPG agent
```

`workstation` imports `base` + `client` (+ `nix-amd-ai` for NPU); `laptop` imports
`base` + `client`. Exposed as `nixosModules.{base,client,server}`.

## Runtime config

Hyprland lives at `dynamic/hypr/hyprland.lua` — edit and reload instantly via
`hyprctl reload` (no rebuild). See that file for the full keybinding table.

## Forking

Edit these four lines in `flake.nix`'s `let` block (plus your own
`hardware-configuration.nix`):

```nix
username = "aperso";
userFullName = "Donghyun Shin";
gitUserName = "apersomany";
gitUserEmail = "aperso@aperso.dev";
```

## Tools

```bash
nix fmt           # Format Nix + Lua (treefmt → nixfmt + stylua)
nh os build .     # Validate without switching
```

Dev shell (`direnv` / `nix develop`) provides `treefmt`, `nil`, `nixd`,
`statix`, `deadnix`, `nh`, and `gh`.

## Dependencies

| Input | Source | Purpose |
|-------|--------|---------|
| `nixpkgs` | `nixos/nixpkgs/nixos-unstable` | Rolling packages |
| `home-manager` | `nix-community/home-manager` | User-level config |
| `kime` | `apersomany/kime` (fork) | Korean input method |
| `nix-amd-ai` | `noamsto/nix-amd-ai` | AMD NPU/ROCm support |

## License

Unlicense
