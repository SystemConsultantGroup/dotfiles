{
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./base.nix
    ./bash.nix
    ./git.nix
    ./alacritty.nix
    ./rofi.nix
    ./flameshot.nix
  ];

  home-manager.users.${username}.home.packages = [
    pkgs.noctalia-shell
    pkgs.cliphist
    pkgs.wl-clipboard
    pkgs.wtype
  ];
}
