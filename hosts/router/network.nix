{
  lib,
  pkgs,
  ...
}:
let
  site = builtins.fromTOML (builtins.readFile ./site.toml);
in
{
  dotfiles.router = {
    inherit (site)
      lan
      wan
      warp
      officeDetection
      ;
  };

  systemd.services."ethtool-${site.wan.interface}" = {
    description = "Disable TSO on ${site.wan.interface}";
    wantedBy = [ "network-pre.target" ];
    before = [ "network-pre.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${lib.getExe pkgs.ethtool} -K ${lib.escapeShellArg site.wan.interface} tso off
    '';
  };
}
