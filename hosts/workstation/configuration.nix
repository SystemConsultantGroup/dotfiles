{
  pkgs,
  inputs,
  ...
}:
{
  networking.hostName = "workstation";
  imports = [
    ./hardware-configuration.nix
    inputs.nix-amd-ai.nixosModules.default
    ../../modules/base
    ../../modules/client
  ];

  hardware.amd-npu = {
    enable = true;
    enableVulkan = true;
    lemonade = {
      port = 13305;
      host = "localhost";
      user = "root";
      flashAttn = "off";
    };
  };
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
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
