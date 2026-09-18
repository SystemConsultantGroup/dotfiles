{ lib, ... }:
{
  options.dotfiles.router = {
    wan = {
      interface = lib.mkOption {
        type = lib.types.str;
        description = "WAN interface name";
      };
      addresses = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Public IPv4 addresses assigned to the WAN interface";
      };
      prefixLength = lib.mkOption {
        type = lib.types.ints.between 0 32;
        description = "WAN IPv4 prefix length";
      };
      gateway = lib.mkOption {
        type = lib.types.str;
        description = "WAN IPv4 default gateway";
      };
    };

    lan = {
      interface = lib.mkOption {
        type = lib.types.str;
        description = "Office LAN interface name";
      };
      address = lib.mkOption {
        type = lib.types.str;
        description = "Router IPv4 address on the office LAN";
      };
      prefixLength = lib.mkOption {
        type = lib.types.ints.between 0 32;
        description = "Office LAN IPv4 prefix length";
      };
      cidr = lib.mkOption {
        type = lib.types.str;
        description = "Office LAN IPv4 network in CIDR notation";
      };
      netmask = lib.mkOption {
        type = lib.types.str;
        description = "Office LAN IPv4 netmask";
      };
      domain = lib.mkOption {
        type = lib.types.str;
        description = "Local DNS domain";
      };
      dhcpPool = {
        start = lib.mkOption {
          type = lib.types.str;
          description = "First address in the office DHCP pool";
        };
        end = lib.mkOption {
          type = lib.types.str;
          description = "Last address in the office DHCP pool";
        };
      };
    };

    cloudflare = {
      mesh = {
        instance = lib.mkOption {
          type = lib.types.str;
          description = "Cloudflare Mesh instance identifier";
        };
        hostInterface = lib.mkOption {
          type = lib.types.str;
          default = "mesh0-host";
          description = "Host side of the Cloudflare Mesh veth pair";
        };
        peerInterface = lib.mkOption {
          type = lib.types.str;
          default = "mesh0-peer";
          description = "Namespace side of the Cloudflare Mesh veth pair";
        };
        clientCidr = lib.mkOption {
          type = lib.types.str;
          default = "100.96.0.0/12";
          description = "IPv4 range assigned to remote Cloudflare Mesh clients";
        };
      };

      officeDetection = {
        address = lib.mkOption {
          type = lib.types.str;
          description = "Cloudflare office-detection IPv4 address";
        };
        cidr = lib.mkOption {
          type = lib.types.str;
          description = "Cloudflare office-detection address in CIDR notation";
        };
        port = lib.mkOption {
          type = lib.types.port;
          description = "Cloudflare office-detection HTTPS port";
        };
      };
    };
  };
}
