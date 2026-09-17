{ lib, pkgs, ... }:
let
  addressing = import ./addressing.nix;
  inherit (addressing) officeLan;

  neighborHook = pkgs.writeShellScript "dnsmasq-neighbor-hook" ''
    action="$1"
    mac="$2"
    address="$3"

    case "$mac" in
      [0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]) ;;
      *) exit 0 ;;
    esac

    case "$action" in
      add|old)
        # Seed the persisted DHCP mapping without making it permanent. Linux
        # can use it immediately and will validate it through normal NUD.
        ${lib.getExe' pkgs.iproute2 "ip"} -4 neigh replace \
          "$address" lladdr "$mac" dev ${lib.escapeShellArg officeLan.interface} nud stale
        ;;
      del)
        # Supplying the MAC avoids deleting a newer mapping for the same IP.
        ${lib.getExe' pkgs.iproute2 "ip"} -4 neigh del \
          "$address" lladdr "$mac" dev ${lib.escapeShellArg officeLan.interface} 2>/dev/null || true
        ;;
    esac
  '';
in
{
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = true;
    settings = {
      inherit (officeLan) interface domain;
      bind-dynamic = true;

      local = "/${officeLan.domain}/";
      domain-needed = true;
      bogus-priv = true;
      stop-dns-rebind = true;

      no-resolv = true;
      server = [
        "1.1.1.1"
        "1.0.0.1"
        "8.8.8.8"
        "8.8.4.4"
      ];

      dhcp-authoritative = true;
      dhcp-range = [
        "${officeLan.dhcpPool.start},${officeLan.dhcpPool.end},${officeLan.netmask},4000s"
      ];
      dhcp-option = [
        "option:router,${officeLan.address}"
        "option:dns-server,${officeLan.address}"
        "option:domain-name,${officeLan.domain}"
        "option:domain-search,${officeLan.domain}"
      ];
      dhcp-script = toString neighborHook;
    };
  };

  # Preserve active leases during the one-time transition from Kea. On its
  # first start, dnsmasq reports imported leases to the hook as `old`, which
  # seeds the neighbor table after a reboot.
  systemd.services.dnsmasq.preStart = lib.mkBefore ''
    kea_leases=/var/lib/private/kea/dhcp4-${officeLan.interface}.leases
    dnsmasq_leases=/var/lib/dnsmasq/dnsmasq.leases

    if [ -s "$kea_leases" ] && [ ! -s "$dnsmasq_leases" ]; then
      ${lib.getExe pkgs.python3} \
        "$kea_leases" "$dnsmasq_leases" ${lib.escapeShellArg officeLan.cidr} <<'PY'
    import csv
    import ipaddress
    import os
    import re
    import sys
    import time

    source, destination, network_text = sys.argv[1:]
    network = ipaddress.ip_network(network_text)
    now = int(time.time())
    latest = {}

    with open(source, newline="", encoding="utf-8") as lease_file:
        for lease in csv.DictReader(lease_file):
            latest[lease["address"]] = lease

    migrated = []
    for address_text, lease in latest.items():
        try:
            address = ipaddress.ip_address(address_text)
            expires = int(lease["expire"])
            state = int(lease.get("state", "0"))
        except (KeyError, TypeError, ValueError):
            continue

        mac = lease.get("hwaddr", "").lower()
        if (
            address not in network
            or expires <= now
            or state != 0
            or re.fullmatch(r"[0-9a-f]{2}(?::[0-9a-f]{2}){5}", mac) is None
        ):
            continue

        hostname = lease.get("hostname", "")
        if re.fullmatch(r"[A-Za-z0-9_.-]+", hostname or "") is None:
            hostname = "*"
        migrated.append((int(address), f"{expires} {mac} {address} {hostname} *\n"))

    temporary = destination + ".migrate"
    with open(temporary, "w", encoding="utf-8") as lease_file:
        for _, line in sorted(migrated):
            lease_file.write(line)
    os.replace(temporary, destination)
    PY
    fi
  '';
}
