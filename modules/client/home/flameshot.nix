{ username, ... }:
{
  # Flameshot 14 uses xdg-desktop-portal for screenshot capture on Wayland.
  # The `useGrimAdapter` / `disabledGrimWarning` settings from earlier
  # versions were removed; passing them now causes flameshot to segfault.
  # Screenshot portal is provided by xdg-desktop-portal-hyprland, which is
  # pulled in by `programs.hyprland.enable` in modules/client/default.nix.
  home-manager.users.${username}.services.flameshot = {
    enable = true;
    settings = { };
  };
}
