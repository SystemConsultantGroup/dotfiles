{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./home
    ./font.nix
  ];
  hardware.graphics.enable = true;
  i18n.inputMethod = {
    enable = true;
    type = "kime";
    package = lib.mkForce inputs.kime.packages.${pkgs.system}.default;
  };
  environment.systemPackages = [
    pkgs.vesktop
    pkgs.firefox
    pkgs.brave
    pkgs.zed-editor
    pkgs.vscode-fhs
    pkgs.nixd
    pkgs.nil
    pkgs.pwvucontrol
    pkgs.bibata-cursors
    pkgs.brightnessctl
  ];
  services = {
    gnome.gnome-keyring.enable = true;
    xserver.xkb = {
      layout = "us";
      options = "terminate:ctrl_alt_bksp";
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --cmd 'uwsm start hyprland-uwsm.desktop'";
    };
  };
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
}
