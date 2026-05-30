{ pkgs, ... }:
{
  boot.kernelParams = [ "amdgpu.ppfeaturemask=0xffffffff" ];

  hardware.amdgpu = {
    opencl.enable = true;
    initrd.enable = true;
  };

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      rocmPackages.rocm-runtime
      rocmPackages.hsakmt
    ];
  };

  environment.systemPackages = with pkgs; [
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
  ];

  environment.variables = {
    HSA_OVERRIDE_GFX_VERSION = "10.3.0"; # gfx1030 (RDNA2 / RX 6800 XT)
  };
}
