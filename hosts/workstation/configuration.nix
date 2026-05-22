{
  pkgs,
  inputs,
  username,
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
    enableFastFlowLM = true;
    enableLemonade = true;
    enableROCm = true;
    enableVulkan = true;
    enableImageGen = true;
    lemonade.user = username;
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  time.timeZone = "Asia/Seoul";
  system.stateVersion = "25.11";
}
