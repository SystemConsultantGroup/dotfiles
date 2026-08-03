{ pkgs, ... }:
let
  alacrittyConfig = pkgs.writeText "alacritty.toml" (
    builtins.readFile ../../files/alacritty/alacritty.toml
  );
in
{
  systemd.user.tmpfiles.rules = [
    "L+ %h/.config/alacritty/alacritty.toml - - - - ${alacrittyConfig}"
  ];
}
