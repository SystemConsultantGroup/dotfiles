{
  config,
  lib,
  notnft,
  ...
}:
let
  inherit (config.dotfiles.router) lan wan;
  inherit (config.dotfiles.router.cloudflare.mesh) clientCidr hostInterface;
  wanAddresses = map (
    address: address.address
  ) config.router.interfaces.${wan.interface}.ipv4.addresses;
in
{
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = false;
  };

  dotfiles.nftables.natTable =
    with notnft.dsl;
    with payload;
    add table.ip {
      postrouting =
        add chain
          {
            type = f: f.nat;
            hook = f: f.postrouting;
            prio = f: f.srcnat;
            policy = f: f.accept;
          }
          [
            (is.eq meta.oifname wan.interface)
            (snat {
              addr.map = {
                key = jhash ip.saddr (builtins.length wanAddresses);
                data = set (
                  lib.imap0 (i: address: [
                    i
                    address
                  ]) wanAddresses
                );
              };
            })
          ]
          [
            (is.eq meta.iifname hostInterface)
            (is.eq meta.oifname lan.interface)
            (is.eq ip.saddr (cidr clientCidr))
            (snat { addr = lan.address; })
          ];
    };
}
