{ pkgs, self, ... }:
{
  home-manager.users.aperso = {
    home.file.".bashrc".source = "${self}/dynamic/bash/.bashrc";
    home.stateVersion = "25.11";

    home.sessionVariables = {
      XCURSOR_THEME = "Bibata-Modern-Ice";
      XCURSOR_SIZE = "24";
      GDK_SCALE = "1";
      GDK_DPI_SCALE = "1.5";
      QT_AUTO_SCREEN_SCALE_FACTOR = "0";
      QT_SCALE_FACTOR = "1.5";
    };

    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "apersomany";
          email = "aperso@aperso.dev";
        };
      };
    };

    gtk = {
      enable = true;
      cursorTheme = {
        name = "Bibata-Modern-Ice";
        package = pkgs.bibata-cursors;
        size = 24;
      };
    };

    qt = {
      enable = true;
      platformTheme.name = "gtk";
    };

    programs.alacritty = {
      enable = true;
      settings = {
        window.padding = {
          x = 8;
          y = 10;
        };
      };
    };

    programs.rofi = {
      enable = true;
      plugins = [ pkgs.rofi-calc ];
    };

    services.flameshot = {
      enable = true;
      settings = {
        General = {
          disabledGrimWarning = true;
          useGrimAdapter = true;
        };
      };
    };
  };
}
