{
  config,
  lib,
  notnft,
  ...
}:
let
  wanAddresses = map (address: address.address) config.router.interfaces.enp0s25.ipv4.addresses;
in
{
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
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
            (is.eq meta.oifname "enp0s25")
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
          ];
      prerouting = add chain {
        type = f: f.nat;
        hook = f: f.prerouting;
        prio = f: f.dstnat;
        policy = f: f.accept;
      };
    };
}
