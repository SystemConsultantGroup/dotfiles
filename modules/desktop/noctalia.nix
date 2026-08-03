{ pkgs, ... }:
let
  noctaliaConfig = pkgs.writeText "noctalia-config.toml" ''
    [theme]
    mode = "dark"
    source = "wallpaper"
    wallpaper_scheme = "m3-fruit-salad"

    [wallpaper]
    directory = "~/dotfiles/files/wallpapers"

    [wallpaper.default]
    path = "~/dotfiles/files/wallpapers/a.jpg"

    [theme.templates]
    enable_builtin_templates = true
    builtin_ids = ["sway", "alacritty", "gtk3", "gtk4", "qt"]
  '';
in
{
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    recommendedServices.enable = true;
  };

  systemd.user.tmpfiles.rules = [
    "L+ %h/.config/noctalia/config.toml - - - - ${noctaliaConfig}"
  ];
}
