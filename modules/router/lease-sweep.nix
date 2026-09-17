{ pkgs, ... }:
{
  systemd = {
    services.fping-lease-sweep = {
      description = "Warm the ARP cache for DHCP clients";
      after = [ "kea-dhcp4-server-enp5s0.service" ];
      requires = [ "kea-dhcp4-server-enp5s0.service" ];
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "fping-lease-sweep" ''
          leasefile="/var/lib/private/kea/dhcp4-enp5s0.leases"
          if [ -s "$leasefile" ]; then
            ${pkgs.gawk}/bin/awk -F, '!/^#/ && NF > 1 {print $1}' "$leasefile" \
              | ${pkgs.findutils}/bin/xargs -r \
                  ${pkgs.fping}/bin/fping -c 1 -t 500 -q 2>/dev/null || true
          fi
        '';
        AmbientCapabilities = [ "CAP_NET_RAW" ];
      };
    };
    timers.fping-lease-sweep = {
      description = "Warm the DHCP client ARP cache every second";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "15s";
        OnUnitActiveSec = "1s";
        AccuracySec = "500ms";
      };
    };
  };
}
