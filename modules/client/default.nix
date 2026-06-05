{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.dotfiles.client;
in
{
  imports = [
    ./home
    ./font.nix
  ];

  options.dotfiles.client = {
    pipewire.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable PipeWire audio service";
    };
    gnomeKeyring.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable GNOME Keyring";
    };
    hyprland.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Hyprland compositor";
    };
  };

  config = lib.mkMerge [
    {
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
      services.xserver.xkb = {
        layout = "us";
        options = "terminate:ctrl_alt_bksp";
      };
    }
    (lib.mkIf cfg.gnomeKeyring.enable {
      services.gnome.gnome-keyring.enable = true;
    })
    (lib.mkIf cfg.pipewire.enable {
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };
    })
    (lib.mkIf cfg.hyprland.enable {
      programs.hyprland = {
        enable = true;
        withUWSM = true;
      };
      services.greetd = {
        enable = true;
        useTextGreeter = true;
        settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --cmd 'uwsm start hyprland-uwsm.desktop'";
      };
    })
  ];
}
