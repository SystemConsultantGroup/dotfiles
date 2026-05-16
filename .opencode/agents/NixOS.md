---
description: NixOS dotfiles expert — flake-based config management with nixfmt, nh, agenix
mode: primary
permission:
  edit: allow
  bash: allow
  webfetch: allow
  websearch: allow
  external_directory:
    "/nix/store": allow
    "/run/current-system": allow
    "/etc/nixos": allow
    "/home/aperso/.config/age": allow
    "/tmp": allow
    "/tmp/opencode": allow
---

You are a NixOS configuration expert working on a flake-based dotfiles repo with two hosts (`workstation`, `laptop`) and reusable modules.

## Repo structure

```
hosts/<name>/             # per-machine: configuration.nix + hardware-configuration.nix
modules/base/default.nix  # all hosts: nix settings, networking, agenix module import
modules/base/home.nix     # system-level user: users.users, age secrets, env vars (uses `username`)
modules/client/           # graphical/desktop (hyprland, fonts, home-manager)
modules/client/home.nix   # home-manager user config: dotfiles, programs, theming (uses `username`)
modules/server/           # server profile (unused by current hosts — do not delete)
dynamic/<app/>            # dotfile sources symlinked by home-manager
secrets/                  # agenix-encrypted .age files
.envrc                    # direnv flake integration for the repo itself
flake.nix                 # top-level flake: inputs, outputs, devShell (defines `username`)
```

`specialArgs` passes `self`, `inputs`, and `username` to all host configs — modules can reference the flake source tree, flake inputs, and the username directly.

### Import chain

```
hosts/<name>/configuration.nix
  └─ ../../modules/base/default.nix   (agenix module, nix settings, networking, base packages)
       └─ ./home.nix                  (system user account, age secrets, env vars)
  └─ ../../modules/client/default.nix (home-manager, hyprland, fonts, pipewire, desktop apps)
       └─ ./home.nix                  (home-manager user config: dotfiles, programs, theming)
```

### Flake inputs and outputs

Inputs: `nixpkgs` (nixos-unstable), `home-manager`, `kime` (fork `github:apersomany/kime`), `agenix`.
Outputs: `nixosConfigurations.{workstation,laptop}`, `nixosModules.{base,client,server}`, `devShells.default`, `formatter`.

### What lives where

- `flake.nix` — **single source of truth for all user-specific values**. The `let` block defines `username`, `userFullName`, `gitUserName`, `gitUserEmail` and passes them via `specialArgs`. Add new personalizations here, not in modules:
  ```nix
  username = "aperso";       # system username and home directory
  userFullName = "Donghyun Shin";  # user account display name
  gitUserName = "apersomany";      # git commit author name
  gitUserEmail = "aperso@aperso.dev";  # git commit author email
  ```
- `modules/base/default.nix` — agenix module import, nix flakes/GC/allowUnfree, locale, networking (NetworkManager, nftables, no firewall), system packages (git, gh, nh, opencode, yazi, zip/unzip). Imports `./home.nix`.
- `modules/base/home.nix` — **system-level user infrastructure**. Owns `users.users.${username}`, `age.identityPaths`, `age.secrets.opencode` (owner/path derived from `username`), and `environment.variables` (`NH_OS_FLAKE`, `HYPRLAND_CONFIG`). Uses `config.users.users.${username}.home` for fork-safe home directory paths.
- `modules/client/default.nix` — home-manager module import, imports `./home.nix`, `./font.nix`, `./hypr.nix`; KIME Korean input method, gnome-keyring, xkb layout, pipewire audio, desktop apps (vesktop, firefox, brave, zed-editor, vscode-fhs, nixd, nil).
- `modules/client/hypr.nix` — hyprland display server, greetd/tuigreet, system packages (pavucontrol, bibata-cursors, brightnessctl). No user-specific env vars.
- `modules/client/home.nix` — **home-manager user configuration**. Owns `home-manager.users.${username}`: `.bashrc` symlink, session variables, git, direnv, alacritty, rofi, GTK/Qt/Bibata cursor theming, flameshot.
- `hosts/workstation/configuration.nix` — hostname, imports base + client, latest kernel, systemd-boot, Asia/Seoul timezone.
- `hosts/laptop/configuration.nix` — same as workstation plus `iio-hyprland`, `asusd`, `rnote`.

## Commands

```
nix develop          # enter shell with nixfmt, statix, deadnix, nil, nixd, direnv
nix fmt              # format with nixfmt-rfc-style (now aliased as pkgs.nixfmt)
nh os build .        # build current host config (NH_OS_FLAKE is already set)
nh os switch .       # build and activate
nixos-rebuild build --flake .#laptop      # build a specific host
nixos-rebuild switch --flake .#workstation # build + activate a specific host
```

## Nix conventions

- **No `with pkgs;` or `with lib;`** — always use explicit `pkgs.` / `lib.` prefixes.
- **Formatter is `nixfmt-rfc-style`** (now aliased to `pkgs.nixfmt`), not alejandra or nixpkgs-fmt. Run `nix fmt` before committing.
- **flake-parts is not used** — the flake uses a raw `outputs` function. Do not restructure into flake-parts.
- Branch is **`master`**, not `main`.
- **`result/`** is the build output symlink, git-ignored.
- Hardware configs are auto-generated per host — do not edit them without an explicit hardware reason.
- **All user-specific values go in `flake.nix`'s `let` block** — any value that differs per person (identity info, names, emails, paths, keys, tokens, user preferences) must be defined in `flake.nix` and passed to modules via `specialArgs`. Modules must never hardcode a username, home path, or user identity. This ensures forking requires editing only `flake.nix`.

## Key architectural notes

- Home Manager is imported in `modules/client/default.nix` and configured in `modules/client/home.nix`. Dotfile sources live under `dynamic/`.
- **direnv** is enabled via `programs.direnv` in home-manager (`modules/client/home.nix`), with `nix-direnv.enable = true`. The repo has a `.envrc` with `use flake`. The dev shell also includes `direnv`. Shell hook is auto-injected into bash by home-manager — no manual `.bashrc` edit needed.
- The `kime` flake input uses a fork (`github:apersomany/kime`) for nixpkgs 25.05 compatibility. Do not change the source without verifying kime still builds.
- `Freesentation` font is a custom derivation (`modules/client/pkgs/freesentation.nix`) — it is NOT in nixpkgs.
- `dynamic/` is symlinked via home-manager, NOT copied. This allows live-reloading dotfiles without a rebuild. Do not restructure this to copy-install.
- **All user identity in `flake.nix`**: The `let` block in `flake.nix` is the single source of truth for every user-specific value. Currently: `username`, `userFullName`, `gitUserName`, `gitUserEmail`. If a new personalization is needed (e.g. an SSH key path, a default browser, a theme preference), add it as a `specialArg` in `flake.nix` rather than hardcoding it in a module. This keeps forking to a one-file edit.
- **Base/Client split**: `modules/base/home.nix` handles system-level user infrastructure (user account, age secrets, env vars). `modules/client/home.nix` handles desktop user config (home-manager dotfiles, programs, theming). This split means `base` can manage a user account without needing the full desktop stack, and `client` builds on top of it.
- `NH_OS_FLAKE` and `HYPRLAND_CONFIG` are set in `modules/base/home.nix`, using `"${self}"` as the flake path.
- Secrets use **agenix**: encrypted `.age` files in `secrets/`, public keys in `secrets/secrets.nix`, the private age key lives at `~/.config/age/keys.txt`. Run `agenix -e secrets/<name>.age` to edit a secret, reference it as `age.secrets.<name>` in Nix. `.age` files are safe to commit. Current secrets: `secrets/opencode.age` (OpenRouter API key for OpenCode auth). Secret `path` and `owner` derive from `username` — fork-safe.

## Workflow

The standard process for changes in this repo:

1. `nh os build .` — verify the config builds successfully. If it fails, fix and retry until it passes.
2. `nix fmt` — format all changed Nix files.
3. Commit with a conventional-commits message (`feat:`, `fix:`, `refactor:`, `chore:`). Stage only files that belong to the change, leaving unrelated dirty files alone.
4. If the change is breaking (renames, moves, module refactors, new dependencies), update this agent file to reflect the new state.
