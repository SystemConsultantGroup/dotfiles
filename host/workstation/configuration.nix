{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../module/base
    ../../module/client
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "workstation";

  time.timeZone = "Asia/Seoul";

  environment.etc."libinput/local-overrides.quirks".text = ''
    [Rapoo Scroll Fix]
    MatchName=Rapoo Rapoo Gaming Device
    AttrEventCode=-REL_WHEEL_HI_RES;-REL_HWHEEL_HI_RES;
  '';

  system.stateVersion = "25.11";
}
