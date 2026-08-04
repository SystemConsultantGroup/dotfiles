{ pkgs, ... }:
let
  noctaliaConfig = pkgs.writeText "noctalia-config.toml" (
    builtins.readFile ../../files/noctalia/config.toml
  );
  noctaliaColors = pkgs.writeText "noctalia-colors.json" (
    builtins.readFile ../../files/noctalia/colors.json
  );
  noctaliaPlugins = pkgs.writeText "noctalia-plugins.json" (
    builtins.readFile ../../files/noctalia/plugins.json
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
    "L+ %h/.config/noctalia/colors.json - - - - ${noctaliaColors}"
    "L+ %h/.config/noctalia/plugins.json - - - - ${noctaliaPlugins}"
  ];
}
