{ lib, pkgs, ... }:
let
  addressing = import ./addressing.nix;
  inherit (addressing) officeLan;
  instance = "scg-skku-router";
  namespace = "mesh-${instance}";
  hostInterface = "mesh0-host";
  meshInterface = "mesh0-peer";
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
        "net.ipv4.conf.mesh0-peer.rp_filter" = 0;
        "net.ipv4.conf.all.src_valid_mark" = 1;
      };
      nftables.textRules = ''
        table inet mesh_filter {
          chain forward {
            type filter hook forward priority filter; policy drop;

            ct state { established, related } accept
            oifname "${meshInterface}" ip daddr ${officeLan.cidr} accept
          }
        }
      '';
    };

    veths.${hostInterface}.peerName = meshInterface;

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
              "100.96.0.0/12"
              "via"
              "172.31.255.2"
            ];
          }
        ];
      };

      ${meshInterface} = {
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
                officeLan.cidr
                "via"
                "172.31.255.1"
              ];
            }
          ];
        };
      };
    };
  };

  virtualisation.oci-containers.containers.${containerName} = {
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

  systemd.services = {
    # Keep namespace-owned setup units in the same restart transaction as the
    # namespace. This preserves the veth across declarative namespace updates.
    "setup-netns-for-mesh0\\x2dpeer" = {
      after = [ "netns-${namespace}.service" ];
      requires = [ "netns-${namespace}.service" ];
      partOf = [ "netns-${namespace}.service" ];
    };
    "network-addresses-mesh0\\x2dpeer".partOf = [ "netns-${namespace}.service" ];
    "sysctl-netns-${namespace}".partOf = [ "netns-${namespace}.service" ];
    "nftables-netns-${namespace}".partOf = [ "netns-${namespace}.service" ];

    ${serviceName} = {
      description = "Cloudflare Mesh node scg-skku/router";
      partOf = [ "netns-${namespace}.service" ];
      after = [
        "network-addresses-mesh0\\x2dhost.service"
        "network-addresses-mesh0\\x2dpeer.service"
        "nftables-netns-${namespace}.service"
        "sysctl-netns-${namespace}.service"
      ];
      requires = [
        "network-addresses-mesh0\\x2dhost.service"
        "network-addresses-mesh0\\x2dpeer.service"
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
