{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dotfiles.router.cloudflare) officeDetection;
  stateDirectory = "cloudflare-office-detection";
in
{
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    virtualHosts."cloudflare-office-detection" = {
      onlySSL = true;
      listen = [
        {
          addr = officeDetection.address;
          inherit (officeDetection) port;
          ssl = true;
        }
      ];
      sslCertificate = "/var/lib/${stateDirectory}/cert.pem";
      sslCertificateKey = "/var/lib/${stateDirectory}/key.pem";
      locations."/".return = "204";
      extraConfig = ''
        access_log off;
      '';
    };
  };

  systemd.services = {
    cloudflare-office-address = {
      description = "Assign the Cloudflare office-detection address";
      wantedBy = [ "network.target" ];
      before = [ "nginx.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${lib.getExe' pkgs.iproute2 "ip"} address replace ${officeDetection.cidr} dev lo
      '';
      preStop = ''
        ${lib.getExe' pkgs.iproute2 "ip"} address del ${officeDetection.cidr} dev lo 2>/dev/null || true
      '';
    };

    cloudflare-office-certificate = {
      description = "Create the Cloudflare office-detection TLS certificate";
      before = [ "nginx.service" ];
      requiredBy = [ "nginx.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = stateDirectory;
        StateDirectoryMode = "0750";
        Group = "nginx";
        UMask = "0027";
      };
      script = ''
        key="$STATE_DIRECTORY/key.pem"
        cert="$STATE_DIRECTORY/cert.pem"

        if [ ! -s "$key" ] || [ ! -s "$cert" ]; then
          work="$(${pkgs.coreutils}/bin/mktemp -d "$STATE_DIRECTORY/.generate.XXXXXX")"
          trap '${pkgs.coreutils}/bin/rm -rf "$work"' EXIT

          ${lib.getExe pkgs.openssl} req \
            -x509 \
            -newkey rsa:4096 \
            -sha256 \
            -days 3650 \
            -nodes \
            -keyout "$work/key.pem" \
            -out "$work/cert.pem" \
            -subj "/CN=cloudflare-office-detection.internal" \
            -addext "subjectAltName=IP:${officeDetection.address}"

          ${pkgs.coreutils}/bin/install -m 0640 "$work/key.pem" "$key"
          ${pkgs.coreutils}/bin/install -m 0644 "$work/cert.pem" "$cert"
        fi

        ${pkgs.coreutils}/bin/chown root:nginx "$key" "$cert"
        ${pkgs.coreutils}/bin/chmod 0640 "$key"
        ${pkgs.coreutils}/bin/chmod 0644 "$cert"
        ${lib.getExe pkgs.openssl} x509 -in "$cert" -noout >/dev/null
        ${lib.getExe pkgs.openssl} pkey -in "$key" -noout >/dev/null
      '';
    };

    nginx = {
      after = [ "cloudflare-office-address.service" ];
      requires = [ "cloudflare-office-address.service" ];
    };
  };
}
