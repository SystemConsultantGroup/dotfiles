{
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./base.nix
    ./alacritty.nix
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
    pkgs.brave
    pkgs.zed-editor
    pkgs.nixd
    pkgs.nil
    pkgs.pwvucontrol
  ];
}
