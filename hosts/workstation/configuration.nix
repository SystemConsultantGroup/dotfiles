{
  pkgs,
  ...
}:
{
  networking.hostName = "workstation";
  imports = [
    ./hardware-configuration.nix
    ../../modules/base
    ../../modules/client
    ../../modules/client/radeon.nix
    ../../modules/client/arc.nix
  ];
  boot = {
    kernelPackages = pkgs.linuxPackages;
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
        memtest86.enable = true;
      };
      efi.canTouchEfiVariables = true;
    };
  };
  services.cloudflare-warp.enable = true;
  time.timeZone = "Asia/Seoul";
  system.stateVersion = "25.11";
}
