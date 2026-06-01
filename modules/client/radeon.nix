_: {
  boot.kernelParams = [ "amdgpu.ppfeaturemask=0xffffffff" ];

  hardware.amdgpu.initrd.enable = true;
}
