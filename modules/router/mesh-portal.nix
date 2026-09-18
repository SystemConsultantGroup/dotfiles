{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dotfiles.router) lan;
  inherit (config.dotfiles.router.cloudflare.mesh) hostInterface;
  portalHost = "router.scg.sh";
  controlSocket = "/run/mesh-routing/control.sock";
  webSocket = "/run/mesh-portal/web.sock";
  routeTable = "100";
  routeMark = "0x100";
  portalSource = pkgs.writeTextFile {
    name = "mesh-portal.py";
    executable = true;
    text = builtins.readFile ./mesh-portal.py;
  };
  portal = pkgs.writeShellApplication {
    name = "mesh-portal";
    runtimeInputs = [
      pkgs.nftables
      pkgs.python3
    ];
    text = ''
      exec ${lib.getExe pkgs.python3} ${portalSource} "$@"
    '';
  };
in
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "scg@scg.skku.ac.kr";
    certs.${portalHost} = {
      dnsProvider = "cloudflare";
      # Enable lego's file-based token interface. The generated plaintext
      # credential binding is replaced with LoadCredentialEncrypted below.
      credentialFiles.CF_DNS_API_TOKEN_FILE = "/dev/null";
      group = "nginx";
    };
  };

  services = {
    dnsmasq.settings.host-record = "${portalHost},${lan.address}";

    nginx.virtualHosts.${portalHost} = {
      onlySSL = true;
      useACMEHost = portalHost;
      listen = [
        {
          addr = lan.address;
          port = 443;
          ssl = true;
        }
      ];
      locations."/" = {
        proxyPass = "http://unix:${webSocket}";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-Proto https;
        '';
      };
      extraConfig = ''
        access_log off;
        add_header Referrer-Policy "no-referrer" always;
        add_header X-Frame-Options "DENY" always;
      '';
    };
  };

  users = {
    groups.mesh-portal = { };
    users = {
      mesh-portal = {
        isSystemUser = true;
        group = "mesh-portal";
      };
      nginx.extraGroups = [ "mesh-portal" ];
    };
  };

  systemd.services = {
    "acme-${portalHost}" = {
      environment.CF_DNS_API_TOKEN_FILE = "%d/CF_DNS_API_TOKEN_FILE";
      serviceConfig = {
        LoadCredential = lib.mkForce [ ];
        LoadCredentialEncrypted = [
          "CF_DNS_API_TOKEN_FILE:/var/lib/secrets/acme-cloudflare-token.cred"
        ];
      };
    };

    mesh-routing-control = {
      description = "Dynamic Cloudflare Mesh client routing control";
      wantedBy = [ "multi-user.target" ];
      after = [
        "dnsmasq.service"
        "nftables-netns-default.service"
      ];
      requires = [ "nftables-netns-default.service" ];
      partOf = [ "nftables-netns-default.service" ];
      serviceConfig = {
        ExecStart = ''
          ${lib.getExe portal} control \
            --socket ${controlSocket} \
            --state-file /var/lib/mesh-routing/clients.json \
            --lease-file /var/lib/dnsmasq/dnsmasq.leases \
            --lan-cidr ${lan.cidr}
        '';
        Restart = "on-failure";
        RestartSec = 2;
        RuntimeDirectory = "mesh-routing";
        RuntimeDirectoryMode = "0750";
        StateDirectory = "mesh-routing";
        StateDirectoryMode = "0700";
        Group = "mesh-portal";
        UMask = "0007";
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
        AmbientCapabilities = [ "CAP_NET_ADMIN" ];
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_NETLINK"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
      };
    };

    mesh-portal = {
      description = "Cloudflare Mesh self-service portal";
      wantedBy = [ "multi-user.target" ];
      after = [ "mesh-routing-control.service" ];
      requires = [ "mesh-routing-control.service" ];
      serviceConfig = {
        ExecStart = ''
          ${lib.getExe portal} web \
            --socket ${webSocket} \
            --control-socket ${controlSocket}
        '';
        Restart = "on-failure";
        RestartSec = 2;
        RuntimeDirectory = "mesh-portal";
        RuntimeDirectoryMode = "0750";
        User = "mesh-portal";
        Group = "mesh-portal";
        UMask = "0007";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
      };
    };
  };

  router = {
    networkNamespaces.default = {
      rules = [
        {
          ipv6 = false;
          extraArgs = [
            "priority"
            "100"
            "fwmark"
            routeMark
            "lookup"
            routeTable
          ];
        }
      ];
      nftables.textRules = ''
        table ip mesh_policy {
          set clients {
            type ipv4_addr
          }

          chain mark_clients {
            type filter hook prerouting priority mangle; policy accept;
            iifname "${lan.interface}" ip saddr @clients meta mark set ${routeMark}
          }
        }
      '';
    };

    interfaces.${hostInterface}.ipv4.routes = [
      {
        extraArgs = [
          "default"
          "via"
          "172.31.255.2"
          "table"
          routeTable
        ];
      }
    ];
  };
}
