{ config, lib, ... }:
let
  inherit (config.dotfiles.router) wan;

  # Spread LAN and Mesh clients across the public addresses by source address.
  snatMap = lib.concatStringsSep ", " (
    lib.imap0 (index: address: "${toString index} : ${address}") wan.addresses
  );
in
{
  networking.nftables.tables.nat = {
    family = "ip";
    content = ''
      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;

        oifname "${wan.interface}" snat to jhash ip saddr mod ${toString (builtins.length wan.addresses)} map { ${snatMap} }
      }
    '';
  };
}
