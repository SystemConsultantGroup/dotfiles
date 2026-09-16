{ pkgs, ... }:
let
  noctaliaConfig = pkgs.writeText "noctalia-config.toml" (
    builtins.readFile ../../files/noctalia/config.toml
  );
in
{
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    recommendedServices.enable = true;
  };

  systemd.user.tmpfiles.rules = [
    "L+ %h/.config/noctalia/config.toml - - - - ${noctaliaConfig}"
    # Noctalia persists settings/state here; without it wallpaper and theme
    # choices are lost and template regeneration breaks. Created by the user
    # manager, so ownership is correct on fresh installs.
    "d %h/.local/state/noctalia 0755 - - -"
  ];
}
