{ lib, pkgs, ... }:
let
  addressing = import ./addressing.nix;
  inherit (addressing) officeDetection;
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
      sslCertificate = "/run/credentials/nginx.service/office-cert.pem";
      sslCertificateKey = "/run/credentials/nginx.service/office-key.pem";
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
        StateDirectoryMode = "0700";
        UMask = "0077";
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

          ${pkgs.coreutils}/bin/install -m 0600 "$work/key.pem" "$key"
          ${pkgs.coreutils}/bin/install -m 0644 "$work/cert.pem" "$cert"
        fi

        ${lib.getExe pkgs.openssl} x509 -in "$cert" -noout >/dev/null
        ${lib.getExe pkgs.openssl} pkey -in "$key" -noout >/dev/null
      '';
    };

    nginx = {
      after = [ "cloudflare-office-address.service" ];
      requires = [ "cloudflare-office-address.service" ];
      serviceConfig.LoadCredential = [
        "office-cert.pem:/var/lib/${stateDirectory}/cert.pem"
        "office-key.pem:/var/lib/${stateDirectory}/key.pem"
      ];
    };
  };
}
