_: {
  fileSystems = {
    "/mnt/storage" = {
      device = "/dev/disk/by-uuid/20B42E70B42E489C";
      fsType = "ntfs-3g";
      options = [
        "uid=1000"
        "gid=100"
        "rw"
        "auto"
        "fmask=0133"
        "dmask=0002"
        "nofail"
      ];
    };
    "/mnt/download" = {
      device = "/dev/disk/by-uuid/D6D8D631D8D6101B";
      fsType = "ntfs-3g";
      options = [
        "uid=1000"
        "gid=100"
        "rw"
        "auto"
        "fmask=0133"
        "dmask=0002"
        "nofail"
      ];
    };
  };
}
