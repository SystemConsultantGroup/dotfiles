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
      pkgs.cliphist
      pkgs.wl-clipboard
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
      waybar = {
        enable = true;
        settings = {
          mainBar = {
            layer = "top";
            position = "top";
            height = 30;
            spacing = 8;
            modules-left = [ "hyprland/workspaces" ];
            modules-center = [ "clock" ];
            modules-right = [
              "pulseaudio"
              "network"
              "battery"
            ];

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
  };
}
