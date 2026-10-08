{ lib, ... }:
let
  inherit (lib) mkOption types;

  # A Waywarp bridge instance. Waywarp derives the link name and IPv4 /30 and
  # IPv6 /126 subnets from the index; the namespace side is the gateway.
  warpInstance = types.submodule (
    { config, ... }:
    {
      options = {
        index = mkOption {
          type = types.ints.between 0 63;
          description = "Waywarp instance index; selects link waywarpINDEX and subnet 169.254.1.(4*INDEX)/30";
        };
        imported = mkOption {
          type = types.bool;
          default = false;
          description = "Whether the instance runs a registration imported with `waywarp import`; the unit is skipped until it exists";
        };
        location = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Required locations, as for `waywarp up --location`";
        };
        via = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Ways to reach the edge, tried in order";
        };
        environmentFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Root-only EnvironmentFile with relay credentials, kept outside the Nix store";
        };
        link = mkOption {
          type = types.str;
          readOnly = true;
          description = "Host-side bridge link";
        };
        gateway = mkOption {
          type = types.str;
          readOnly = true;
          description = "Namespace-side IPv4 address of the bridge link";
        };
        gateway6 = mkOption {
          type = types.str;
          readOnly = true;
          description = "Namespace-side IPv6 address of the bridge link";
        };
      };
      config = {
        link = "waywarp${toString config.index}";
        gateway = "169.254.1.${toString (4 * config.index + 1)}";
        gateway6 = "fd77:6179:7761:7270::${lib.toHexString (4 * config.index + 1)}";
      };
    }
  );
in
{
  options.dotfiles.router = {
    wan = {
      interface = mkOption {
        type = types.str;
        description = "WAN interface name";
      };
      addresses = mkOption {
        type = types.nonEmptyListOf types.str;
        description = "Public IPv4 addresses on the WAN interface; the first is the router's own source address";
      };
      prefixLength = mkOption {
        type = types.ints.between 0 32;
        description = "WAN IPv4 prefix length";
      };
      gateway = mkOption {
        type = types.str;
        description = "WAN IPv4 default gateway";
      };
    };

    lan = {
      interface = mkOption {
        type = types.str;
        description = "Office LAN interface name";
      };
      address = mkOption {
        type = types.str;
        description = "Router IPv4 address on the office LAN";
      };
      prefixLength = mkOption {
        type = types.ints.between 0 32;
        description = "Office LAN IPv4 prefix length";
      };
      cidr = mkOption {
        type = types.str;
        description = "Office LAN IPv4 network in CIDR notation";
      };
      netmask = mkOption {
        type = types.str;
        description = "Office LAN IPv4 netmask";
      };
      domain = mkOption {
        type = types.str;
        description = "Local DNS domain";
      };
      dhcpPool = {
        start = mkOption {
          type = types.str;
          description = "First address in the office DHCP pool";
        };
        end = mkOption {
          type = types.str;
          description = "Last address in the office DHCP pool";
        };
      };
    };

    meshCidr = mkOption {
      type = types.str;
      default = "100.96.0.0/12";
      description = "IPv4 range Cloudflare assigns to Mesh clients";
    };

    warp = {
      mesh = mkOption {
        type = warpInstance;
        description = "Mesh node joined with the office LAN; its clients may also exit through the WAN";
      };
      mesh-jp = mkOption {
        type = warpInstance;
        description = "Mesh node whose clients exit only through warp-jp";
      };
      warp-jp = mkOption {
        type = warpInstance;
        description = "WARP client that exits in Japan";
      };
    };

    officeDetection = {
      address = mkOption {
        type = types.str;
        description = "Cloudflare office-detection IPv4 address";
      };
      cidr = mkOption {
        type = types.str;
        description = "Cloudflare office-detection address in CIDR notation";
      };
      port = mkOption {
        type = types.port;
        description = "Cloudflare office-detection HTTPS port";
      };
    };
  };
}
