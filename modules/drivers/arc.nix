{ pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    extraPackages = [
      pkgs.intel-media-driver
    ];
  };
  # DG2 HuC/GSC firmware ships in linux-firmware, which NixOS only pulls in
  # when redistributable firmware is enabled (hardware.firmware is empty by
  # default). Required for the Intel Arc A750 on this host.
  hardware.enableRedistributableFirmware = true;
}
