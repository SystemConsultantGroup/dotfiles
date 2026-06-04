{
  pkgs,
  username,
  gitUserName,
  gitUserEmail,
  ...
}:
{
  home-manager.users.${username} = {
    home.stateVersion = "25.11";

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "firefox.desktop";
        "text/xml" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/about" = "firefox.desktop";
        "x-scheme-handler/unknown" = "firefox.desktop";
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

    home.packages = [
      pkgs.noctalia-shell
      pkgs.cliphist
      pkgs.wl-clipboard
      pkgs.wtype
    ];

    services.flameshot = {
      enable = true;
      settings = {
        General = {
          disabledGrimWarning = true;
          useGrimAdapter = true;
        };
      };
    };

    programs = {
      bash = {
        enable = true;
        bashrcExtra = ''
          export PS1="\[\033[1;32m\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\] "
        '';
      };
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
      git = {
        enable = true;
        settings = {
          user = {
            name = gitUserName;
            email = gitUserEmail;
          };
        };
      };
      alacritty = {
        enable = true;
        settings = {
          window.padding = {
            x = 8;
            y = 10;
          };
        };
      };
      rofi = {
        enable = true;
        plugins = [ pkgs.rofi-calc ];
      };
    };
  };
}
