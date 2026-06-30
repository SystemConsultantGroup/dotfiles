{
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./xdg.nix
    ./gtk.nix
    ./qt.nix
    ./alacritty.nix
    ./hyprland.nix
    ./rofi.nix
    ./flameshot.nix
  ];

  home-manager.users.${username}.home.packages = [
    pkgs.noctalia-shell
    pkgs.cliphist
    pkgs.wl-clipboard
    pkgs.wtype
    pkgs.vesktop
    pkgs.firefox
    pkgs.chromium
    pkgs.nautilus
    pkgs.zed-editor
    pkgs.nixd
    pkgs.nil
    pkgs.pwvucontrol
  ];
}
