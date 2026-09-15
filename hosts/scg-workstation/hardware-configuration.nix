# Generated for scg-workstation (SAMSUNG MZVL21T0HCLR 1TB, btrfs).
# Mirrors `nixos-generate-config --root /mnt` output for UUIDs
# 5bf40ce6-75c8-4141-82cc-8b955da82372 (nixos) and 7718-4526 (BOOT),
# plus compress/ssd/noatime tuning.
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    initrd.kernelModules = [ ];
    # btrfs lives in initrd for /nix mount.
    initrd.supportedFilesystems = [ "btrfs" ];
    supportedFilesystems = [ "btrfs" ];
    kernelModules = [ "kvm-amd" ];
    extraModulePackages = [ ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/5bf40ce6-75c8-4141-82cc-8b955da82372";
    fsType = "btrfs";
    options = [
      "subvol=@"
      "compress=zstd"
      "ssd"
      "noatime"
      "space_cache=v2"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/5bf40ce6-75c8-4141-82cc-8b955da82372";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress=zstd"
      "ssd"
      "noatime"
      "space_cache=v2"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/5bf40ce6-75c8-4141-82cc-8b955da82372";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd"
      "ssd"
      "noatime"
      "space_cache=v2"
    ];
  };

  fileSystems."/.snapshots" = {
    device = "/dev/disk/by-uuid/5bf40ce6-75c8-4141-82cc-8b955da82372";
    fsType = "btrfs";
    options = [
      "subvol=@snap"
      "compress=zstd"
      "ssd"
      "noatime"
      "space_cache=v2"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/7718-4526";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
