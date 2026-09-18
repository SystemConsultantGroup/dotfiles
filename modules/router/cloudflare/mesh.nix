{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dotfiles.router) lan;
  inherit (config.dotfiles.router.cloudflare.mesh)
    clientCidr
    hostInterface
    instance
    peerInterface
    ;
  namespace = "mesh-${instance}";
  escapedHostInterface = lib.replaceStrings [ "-" ] [ "\\x2d" ] hostInterface;
  escapedPeerInterface = lib.replaceStrings [ "-" ] [ "\\x2d" ] peerInterface;
  containerName = "cloudflare-mesh";
  serviceName = "podman-${containerName}";
  stateDirectory = "cloudflare-mesh-${instance}";
  statePath = "/var/lib/${stateDirectory}";
  tokenPath = "/var/lib/secrets/mesh-${instance}.token";
  tokenSecret = "cloudflare-mesh-${instance}-token";
  tokenHashPath = "${statePath}/.mesh-token.sha256";
  image = "docker.io/cloudflare/mesh@sha256:b07e759879b752d73947ebf5c0b17d6146f310b671942546876095863d5ab39d";
  prepareContainer = pkgs.writeShellApplication {
    name = "prepare-cloudflare-mesh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.podman
    ];
    text = ''
      token_file="$CREDENTIALS_DIRECTORY/mesh-token"
      token_hash="$(sha256sum "$token_file" | cut -d ' ' -f1)"

      install -d -m 0700 ${statePath}
      if [ ! -r ${tokenHashPath} ] || [ "$(cat ${tokenHashPath})" != "$token_hash" ]; then
        # Registration state takes precedence over MESH_NODE_TOKEN. Discard it
        # when the token changes so the container enrolls the intended node.
        find ${statePath} -mindepth 1 -delete
        printf '%s\n' "$token_hash" > ${tokenHashPath}
        chmod 0600 ${tokenHashPath}
      fi

      # Command substitution strips the credential's trailing newline, which
      # warp-cli otherwise treats as part of (and invalidates) the token.
      token="$(cat "$token_file")"

      # Podman injects this secret as MESH_NODE_TOKEN without recording the
      # token in the Nix store, unit command line, or container configuration.
      printf '%s' "$token" | podman secret create --replace ${tokenSecret} - >/dev/null
      unset token
    '';
  };
  prepareEgress = pkgs.writeShellApplication {
    name = "prepare-cloudflare-mesh-egress";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.iproute2
    ];
    text = ''
      ip -n ${lib.escapeShellArg namespace} route replace \
        blackhole default table 100 metric 32767

      attempt=0
      while (( attempt < 30 )); do
        if ip -n ${lib.escapeShellArg namespace} link show CloudflareWARP >/dev/null 2>&1; then
          exec ip -n ${lib.escapeShellArg namespace} route replace \
            default dev CloudflareWARP table 100 metric 100
        fi
        attempt=$((attempt + 1))
        sleep 1
      done
      echo "CloudflareWARP did not appear in namespace ${namespace}" >&2
      exit 1
    '';
  };
in
{
  systemd.tmpfiles.rules = [
    "d ${statePath} 0700 root root -"
  ];

  router = {
    networkNamespaces.${namespace} = {
      extraStartCommands = "ip link set lo up";
      sysctl = {
        "net.ipv4.ip_forward" = true;
        "net.ipv4.conf.all.rp_filter" = 0;
        "net.ipv4.conf.default.rp_filter" = 0;
        "net.ipv4.conf.${peerInterface}.rp_filter" = 0;
        "net.ipv4.conf.all.src_valid_mark" = 1;
      };
      rules = [
        {
          ipv6 = false;
          extraArgs = [
            "priority"
            "100"
            "iif"
            peerInterface
            "lookup"
            "100"
          ];
        }
      ];
      nftables.textRules = ''
        table inet mesh_filter {
          chain forward {
            type filter hook forward priority filter; policy drop;

            ct state { established, related } accept
            iifname "${peerInterface}" oifname "CloudflareWARP" ip saddr ${lan.cidr} accept
            iifname "CloudflareWARP" oifname "${peerInterface}" ip daddr ${lan.cidr} accept
            oifname "${peerInterface}" ip daddr ${lan.cidr} accept
          }
        }

        table ip mesh_nat {
          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            oifname "CloudflareWARP" ip saddr ${lan.cidr} masquerade
          }
        }
      '';
    };

    veths.${hostInterface}.peerName = peerInterface;

    interfaces = {
      ${hostInterface}.ipv4 = {
        addresses = [
          {
            address = "172.31.255.1";
            prefixLength = 30;
          }
        ];
        routes = [
          {
            extraArgs = [
              clientCidr
              "via"
              "172.31.255.2"
            ];
          }
        ];
      };

      ${peerInterface} = {
        networkNamespace = namespace;
        dependentServices = [ serviceName ];
        ipv4 = {
          addresses = [
            {
              address = "172.31.255.2";
              prefixLength = 30;
            }
          ];
          routes = [
            {
              extraArgs = [
                "default"
                "via"
                "172.31.255.1"
              ];
            }
            {
              extraArgs = [
                lan.cidr
                "via"
                "172.31.255.1"
              ];
            }
          ];
        };
      };
    };
  };

  virtualisation = {
    podman.enable = true;
    oci-containers.containers.${containerName} = {
      inherit image;
      environment.SRCNAT_ENABLED = "false";
      capabilities = {
        NET_ADMIN = true;
        NET_RAW = true;
      };
      devices = [ "/dev/net/tun:/dev/net/tun" ];
      volumes = [ "${statePath}:/var/lib/cloudflare-warp" ];
      networks = [ "ns:/run/netns/${namespace}" ];
      extraOptions = [
        "--secret=${tokenSecret},type=env,target=MESH_NODE_TOKEN"
      ];
    };
  };

  systemd.services = {
    # Keep namespace-owned setup units in the same restart transaction as the
    # namespace. This preserves the veth across declarative namespace updates.
    "setup-netns-for-${escapedPeerInterface}" = {
      after = [ "netns-${namespace}.service" ];
      requires = [ "netns-${namespace}.service" ];
      partOf = [ "netns-${namespace}.service" ];
    };
    "network-addresses-${escapedPeerInterface}".partOf = [ "netns-${namespace}.service" ];
    "sysctl-netns-${namespace}".partOf = [ "netns-${namespace}.service" ];
    "nftables-netns-${namespace}".partOf = [ "netns-${namespace}.service" ];

    cloudflare-mesh-egress = {
      description = "Configure Cloudflare Mesh Internet egress";
      wantedBy = [ "multi-user.target" ];
      after = [ "${serviceName}.service" ];
      requires = [ "${serviceName}.service" ];
      partOf = [ "netns-${namespace}.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${prepareEgress}/bin/prepare-cloudflare-mesh-egress";
      };
    };

    ${serviceName} = {
      description = "Cloudflare Mesh node ${instance}";
      partOf = [ "netns-${namespace}.service" ];
      after = [
        "network-addresses-${escapedHostInterface}.service"
        "network-addresses-${escapedPeerInterface}.service"
        "nftables-netns-${namespace}.service"
        "sysctl-netns-${namespace}.service"
      ];
      requires = [
        "network-addresses-${escapedHostInterface}.service"
        "network-addresses-${escapedPeerInterface}.service"
        "nftables-netns-${namespace}.service"
        "sysctl-netns-${namespace}.service"
      ];
      serviceConfig = {
        LoadCredential = "mesh-token:${tokenPath}";
        ExecStartPre = lib.mkAfter [ "${prepareContainer}/bin/prepare-cloudflare-mesh" ];
      };
    };
  };
}
