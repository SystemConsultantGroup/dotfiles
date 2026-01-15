{ config, pkgs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  networking.nameservers = [ "1.1.1.1" "8.8.8.8" "1.0.0.1" "8.8.4.4" ];
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;
  networking.firewall.enable = false;

  users.users.aperso = {
    isNormalUser = true;
    description = "Donghyun Shin";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  environment.systemPackages = with pkgs; [
    zip
    unzip
    git
    gh
    nh
    opencode
    sops
    age
    ssh-to-age
    rclone
    fuse
  ];

  environment.variables.NH_OS_FLAKE = "/home/aperso/dotfiles";

  sops.secrets."rclone/erudites/access_key_id" = { owner = "aperso"; };
  sops.secrets."rclone/erudites/secret_access_key" = { owner = "aperso"; };
  sops.secrets."rclone/erudites/endpoint" = { owner = "aperso"; };

  sops.templates."rclone.conf" = {
    owner = "aperso";
    content = ''
      [erudites]
      type = s3
      provider = Cloudflare
      access_key_id = ${config.sops.secrets."rclone/erudites/access_key_id".placeholder}
      secret_access_key = ${config.sops.secrets."rclone/erudites/secret_access_key".placeholder}
      endpoint = ${config.sops.secrets."rclone/erudites/endpoint".placeholder}
      acl = private
    '';
  };

  systemd.services.rclone-erudites-mount = {
    description = "Mount Erudites R2 Bucket";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "aperso";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/r2/erudites";
      ExecStart = "${pkgs.rclone}/bin/rclone mount erudites: %h/r2/erudites --config ${config.sops.templates."rclone.conf".path} --vfs-cache-mode full";
      ExecStop = "${pkgs.fuse}/bin/fusermount -u %h/r2/erudites";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
}
