{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dotfiles.router) lan;
  inherit (config.dotfiles.router.cloudflare.mesh) hostInterface;

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
          "$address" lladdr "$mac" dev ${lib.escapeShellArg lan.interface} nud stale
        ;;
      del)
        # Supplying the MAC avoids deleting a newer mapping for the same IP.
        ${lib.getExe' pkgs.iproute2 "ip"} -4 neigh del \
          "$address" lladdr "$mac" dev ${lib.escapeShellArg lan.interface} 2>/dev/null || true
        ;;
    esac
  '';
in
{
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = true;
    settings = {
      inherit (lan) domain;
      interface = [
        lan.interface
        hostInterface
      ];
      no-dhcp-interface = hostInterface;

      local = "/${lan.domain}/";
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
        "${lan.dhcpPool.start},${lan.dhcpPool.end},${lan.netmask},4000s"
      ];
      dhcp-option = [
        "option:router,${lan.address}"
        "option:dns-server,${lan.address}"
        "option:domain-name,${lan.domain}"
        "option:domain-search,${lan.domain}"
      ];
      dhcp-script = toString neighborHook;
    };
  };
}
