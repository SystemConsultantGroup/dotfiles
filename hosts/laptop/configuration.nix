{ pkgs, username, ... }:
{
  networking.hostName = "laptop";
  programs.iio-hyprland.enable = true;
  services.asusd.enable = true;
  home-manager.users.${username}.home.packages = [
    pkgs.rnote
  ];
  imports = [
    ./hardware-configuration.nix
    ../../modules/base
    ../../modules/client
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
  time.timeZone = "Asia/Seoul";
  system.stateVersion = "25.11";
}
