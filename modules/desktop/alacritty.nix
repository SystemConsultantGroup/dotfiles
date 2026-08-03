{ pkgs, ... }:
let
  alacrittyConfig = pkgs.writeText "alacritty.toml" ''
    [general]
    import = [
        "~/.config/alacritty/themes/noctalia.toml"
    ]

    [window]
    padding = { x = 8, y = 10 }
  '';
in
{
  systemd.user.tmpfiles.rules = [
    "L+ %h/.config/alacritty/alacritty.toml - - - - ${alacrittyConfig}"
  ];
}
