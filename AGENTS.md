# AGENTS.md

## Repo overview

NixOS dotfiles — flake-based, two hosts (`workstation`, `laptop`), plus reusable modules.

```
host/<name>/              # per-machine: configuration.nix + hardware-configuration.nix
module/base/              # all hosts (users, networking, nix settings)
module/client/            # graphical/desktop (hyprland, fonts, home-manager)
module/server/            # server profile (unused by current hosts — do not delete)
module/user/aperso.nix    # home-manager user config (dotfile symlinks, DE theming)
config/<app>/             # dotfile sources symlinked by home-manager
```

`specialArgs` passes `self` and `inputs` to all host configs — modules can reference the flake source tree and flake inputs directly.

## Commands

```
nix develop          # enter shell with nixfmt, statix, deadnix, nil, nixd
nix fmt              # format with nixfmt-rfc-style
nh os build .        # build current host config (NH_OS_FLAKE is already set)
nh os switch .       # build and activate
nixos-rebuild build --flake .#laptop      # build a specific host
nixos-rebuild switch --flake .#workstation # build + activate a specific host
```

## Nix conventions

- **No `with pkgs;` or `with lib;`** — always use explicit `pkgs.` / `lib.` prefixes.
- **Formatter is `nixfmt-rfc-style`**, not alejandra or nixpkgs-fmt. Run `nix fmt` before committing.
- **flake-parts is not used** — the flake uses a raw `outputs` function. Do not restructure into flake-parts.
- Branch is **`master`**, not `main`.
- **`result/`** is the build output symlink, git-ignored.
- Hardware configs are auto-generated per host — do not edit them without an explicit hardware reason.

## Key architectural notes

- Home Manager is imported in `module/client/default.nix` and configured in `module/user/aperso.nix`. Dotfile sources live under `config/`.
- The `kime` flake input uses a fork (`github:apersomany/kime`) for nixpkgs 25.05 compatibility. Do not change the source without verifying kime still builds.
- `Freesentation` font is a custom derivation (`module/client/pkgs/freesentation.nix`) — it is NOT in nixpkgs.
- `config/` is symlinked via home-manager, NOT copied. This allows live-reloading dotfiles without a rebuild. Do not restructure this to copy-install.
- `module/base/default.nix` sets `NH_OS_FLAKE` to `/home/aperso/dotfiles` so `nh` commands work from any directory.

## Workflow for every change

After making a change, always run all three steps below — do not wait for the user to ask.

1. `nh os build .` — verify the config builds successfully. If it fails, keep fixing and retrying until it passes.
2. `nix fmt` — format all changed Nix files.
3. Commit with a conventional-commits message (`feat:`, `fix:`, `refactor:`, `chore:`). Only stage files that belong to the change — leave unrelated dirty files alone.
4. If the change is breaking (renames, moves, module refactors, new dependencies), update this file.
