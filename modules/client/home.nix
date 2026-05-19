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

    programs.bash = {
      enable = true;
      bashrcExtra = ''
        export PS1="\[\033[1;32m\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\] "
      '';
    };

    home.sessionVariables = {
      XCURSOR_THEME = "Bibata-Modern-Ice";
      XCURSOR_SIZE = "24";
      GDK_SCALE = "1";
      GDK_DPI_SCALE = "1.5";
      QT_AUTO_SCREEN_SCALE_FACTOR = "0";
      QT_SCALE_FACTOR = "1.5";
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    programs.git = {
      enable = true;
      settings = {
        user = {
          name = gitUserName;
          email = gitUserEmail;
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

    programs.waybar = {
      enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 30;
          spacing = 8;
          modules-left = [ "hyprland/workspaces" ];
          modules-center = [ "clock" ];
          modules-right = [ "pulseaudio" "network" "battery" ];

          clock = {
            format = "{:%Y-%m-%d %H:%M}";
          };

          "hyprland/workspaces" = {
            format = "{name}";
          };

          pulseaudio = {
            format = "VOL {volume}%";
            format-muted = "MUTED";
            scroll-step = 5;
          };

          network = {
            format = "{ifname} {ipaddr}";
          };

          battery = {
            format = "BAT {capacity}%";
            format-charging = "CHR {capacity}%";
          };
        };
      };
      style = ''
        * {
          font-family: "JetBrainsMono Nerd Font";
          font-size: 13px;
        }
        window#waybar {
          background: rgba(30, 30, 46, 0.9);
          color: #cdd6f4;
        }
        #clock, #battery, #network, #pulseaudio {
          padding: 0 12px;
        }
        #window {
          color: #f5c2e7;
        }
        #workspaces {
          margin: 0 4px;
        }
        #workspaces button {
          color: #f5c2e7;
          padding: 0 4px;
        }
        #workspaces button.active {
          color: #a6e3a1;
        }
      '';
    };
  };
}
