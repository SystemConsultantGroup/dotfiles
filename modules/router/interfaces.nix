{ config, ... }:
let
  inherit (config.dotfiles.router) lan wan;
in
{
  networking.useNetworkd = true;

  # dnsmasq is the resolver; resolved would compete for port 53.
  services.resolved.enable = false;

  systemd.network = {
    enable = true;

    # Waywarp and the policy-routing unit own routes and rules that networkd
    # did not create. Leave them in place when networkd reconfigures links.
    config.networkConfig = {
      ManageForeignRoutes = false;
      ManageForeignRoutingPolicyRules = false;
    };

    networks = {
      "10-wan" = {
        matchConfig.Name = wan.interface;
        address = map (address: "${address}/${toString wan.prefixLength}") wan.addresses;
        routes = [
          {
            Gateway = wan.gateway;
            PreferredSource = builtins.head wan.addresses;
          }
        ];
        networkConfig = {
          IPv6AcceptRA = false;
          LinkLocalAddressing = "ipv6";
        };
        linkConfig.RequiredForOnline = "routable";
      };

      "10-lan" = {
        matchConfig.Name = lan.interface;
        address = [ "${lan.address}/${toString lan.prefixLength}" ];
        networkConfig = {
          IPv6AcceptRA = false;
          LinkLocalAddressing = "ipv6";
          # Keep the LAN address, and thus DHCP and DNS, without a carrier.
          ConfigureWithoutCarrier = true;
        };
        linkConfig.RequiredForOnline = "no";
      };
    };
  };
}
