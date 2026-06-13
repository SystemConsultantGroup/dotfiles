{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
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
    pkgs.vscode-fhs
    pkgs.bibata-cursors
    pkgs.brightnessctl
  ];

  services = {
    xserver.xkb = {
      layout = "us";
      options = "terminate:ctrl_alt_bksp";
    };

    gnome.gnome-keyring.enable = true;

    gvfs.enable = true;

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
