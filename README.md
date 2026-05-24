# dotfiles

NixOS configuration managed as a flake. This repo controls the full system configuration for the `router` host.

## Structure

```
flake.nix              Entry point; defines nixosConfigurations
hosts/router/           Per-host config (hardware, networking, hostname)
modules/base/           Shared base settings (users, packages, flakes)
modules/client/         Desktop/GUI packages and services
modules/server/         Server services (SSH, Podman)
dynamic/                Dotfiles placed into $HOME via home-manager
```

## How to make changes

### 1. Edit with opencode

`opencode` is installed on the system. Open it from the dotfiles directory:

```
cd ~/dotfiles
opencode
```

Describe what you want to change in plain language. For example:
- "Add ripgrep to system packages in the base module"
- "Enable docker instead of podman"
- "Add a new hyprland keybinding"

opencode will read the relevant files and make the edits for you.

### 2. Apply with nh

After making changes, rebuild and switch to the new configuration:

```
nh os switch
```

This uses the flake at `~/dotfiles` (set by `NH_OS_FLAKE`). No need to remember `nixos-rebuild` flags.

To just build without activating (useful for checking errors):

```
nh os build
```

## Recovering on a fresh NixOS install

If the machine dies, here's how to get back to this configuration from a NixOS live USB:

1. Install NixOS normally. The partition scheme doesn't matter much since `nh` will rebuild the whole system.

2. Install git and gh, then authenticate:

   ```
   nix-shell -p git gh
   gh auth login
   ```

3. Clone this repo:

   ```
   cd ~
   gh repo clone SystemConsultantGroup/dotfiles dotfiles
   ```

4. Regenerate the hardware config for the new machine. It must match the actual hardware (disk UUIDs, kernel modules, etc.):

   ```
   cd ~/dotfiles
   sudo nixos-generate-config --show > hosts/router/hardware-configuration.nix
   ```

   Review the generated file — make sure disk UUIDs and mount points are correct.

5. Rebuild:

   ```
   sudo nixos-rebuild switch --flake .#router
   ```

   After this first manual rebuild, `nh` and `opencode` will be installed and the `NH_OS_FLAKE` env var will be set. From here on you can use `nh os switch` as normal.

## Tips

- **Check your edit before switching.** `nh os build` catches eval and build errors without touching the running system.
- **Look at existing modules first.** The `modules/` directory is split by role (base, client, server). Add packages and services to the right one.
- **Home-manager files** live in `dynamic/` and are wired up in `modules/client/home.nix` via `home-manager.users.scg`.
- **Adding a new host:** copy `hosts/router/` to a new directory, create a matching entry in `flake.nix` under `nixosConfigurations`, and run `nh os switch --hostname <name>`. For the initial rebuild use `sudo nixos-rebuild switch --flake .#<name>`.
