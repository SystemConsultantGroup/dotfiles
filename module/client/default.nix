{
  pkgs,
  self,
  inputs,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./font.nix
    ./hypr.nix
  ];
  services.gnome.gnome-keyring.enable = true;
  services.xserver.xkb.layout = "us";
  environment.systemPackages = with pkgs; [
    vesktop
    firefox
    zed-editor
    vscode-fhs
    nixd
    nil
  ];
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  services.xserver.xkb.options = "terminate:ctrl_alt_bksp";
  home-manager.users.aperso = {
    home.file.".bashrc".source = "${self}/config/bash/.bashrc";
    home.stateVersion = "25.11";
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "apersomany";
          email = "aperso@aperso.dev";
        };
      };
    };
  };
}
