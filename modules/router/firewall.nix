{ notnft, ... }:
{
  dotfiles.nftables.filterTable =
    with notnft.dsl;
    with payload;
    add table.ip {
      forward =
        add chain
          {
            type = f: f.filter;
            hook = f: f.forward;
            prio = f: f.filter;
            policy = f: f.drop;
          }
          [
            (vmap ct.state {
              established = accept;
              related = accept;
            })
          ]
          [
            (is.eq meta.iifname "enp5s0")
            (is.eq meta.oifname "enp0s25")
            accept
          ];
    };
}
