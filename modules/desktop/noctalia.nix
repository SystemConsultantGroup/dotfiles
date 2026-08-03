{ pkgs, ... }:
let
  noctaliaConfig = pkgs.writeText "noctalia-config.toml" (builtins.readFile ./noctalia-config.toml);
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
