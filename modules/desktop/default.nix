{
  lib,
  pkgs,
  inputs,
  username,
  ...
}:
let
  kimePkgs = inputs.kime.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  vesktop = pkgs.vesktop.overrideAttrs (old: {
    postFixup =
      lib.replaceString "--ozone-platform-hint=auto" "--ozone-platform=wayland" old.postFixup
      + ''
        wrapProgram $out/bin/vesktop --set NIXOS_OZONE_WL 1
      '';
  });
  kime = inputs.kime.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    # Kime still uses the deprecated xorg.libxcb alias.
    buildInputs = (lib.take 2 old.buildInputs) ++ [ kimePkgs.libxcb ] ++ (lib.drop 3 old.buildInputs);
    # upstream flake ships a stale cargo vendor hash for its own lock (5c58caf)
    cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
      inherit (old) src;
      hash = "sha256-XbFKh+EwvuQvfNxpKtXVWuzpCKJJy+vKAgZRYjSVMvU=";
    };
    postFixup = ''
      patchelf --add-rpath ${pkgs.wayland}/lib $out/bin/kime-wayland
    '';
  });
  persway = inputs.persway.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    src = pkgs.applyPatches {
      inherit (old) src;
      patches = [ ../../patches/persway-stack-main-right.patch ];
    };
  });
in
{
  imports = [
    ./alacritty.nix
    ./font.nix
    ./noctalia.nix
    ./sway.nix
  ];

  i18n.inputMethod = {
    enable = true;
    type = "kime";
    package = lib.mkForce kime;
  };

  services = {
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
        user = "greeter";
      };
    };

    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };

    gnome.gnome-keyring.enable = true;

    gvfs.enable = true;
  };

  xdg.portal.wlr.enable = true;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.user == "${username}" &&
        subject.active &&
        subject.local &&
        [
          "org.freedesktop.udisks2.filesystem-mount",
          "org.freedesktop.udisks2.filesystem-mount-system",
          "org.freedesktop.udisks2.filesystem-unmount-others"
        ].indexOf(action.id) >= 0
      ) {
        return polkit.Result.YES;
      }
    });
  '';

  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      {
        settings."org/gnome/desktop/interface".icon-theme = "Papirus-Dark";
      }
    ];
  };

  environment.systemPackages = [
    pkgs.alacritty
    pkgs.alacritty.terminfo
    pkgs.bibata-cursors
    pkgs.brightnessctl
    pkgs.celluloid
    pkgs.firefox
    pkgs.flameshot
    pkgs.libva-utils
    pkgs.loupe
    pkgs.nautilus
    pkgs.nixd
    pkgs.papirus-icon-theme
    vesktop
    pkgs.vscode-fhs
    pkgs.wl-clipboard
    persway
  ];
}
