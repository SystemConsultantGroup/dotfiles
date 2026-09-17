{
  pkgs,
  username,
  userFullName,
  gitUserName,
  gitUserEmail,
  ...
}:
{
  imports = [ ./pi.nix ];

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "@wheel"
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  nixpkgs.config.allowUnfree = true;
  security.sudo.wheelNeedsPassword = false;

  networking = {
    networkmanager.enable = false;
    nftables.enable = true;
    firewall.enable = false;
  };

  environment = {
    systemPackages = [
      pkgs.bat
      pkgs.fd
      pkgs.fzf
      pkgs.gh
      pkgs.git
      pkgs.hping
      pkgs.jq
      pkgs.killall
      pkgs.mtr
      pkgs.nh
      pkgs.nix-search-cli
      pkgs.ripgrep
      pkgs.unzip
      pkgs.zip
    ];
    variables.SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    sessionVariables.NH_OS_FLAKE = "/home/${username}/dotfiles";
  };

  programs = {
    bash = {
      promptInit = ''
        export PS1="\[\033[1;32m\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\] "
      '';
      interactiveShellInit = ''
        export PATH="$HOME/.local/bin:$PATH"

        if command -v gh &>/dev/null; then
          export GITHUB_TOKEN="$(gh auth token 2>/dev/null)"
        fi
      '';
    };
    git = {
      enable = true;
      config = {
        user = {
          name = gitUserName;
          email = gitUserEmail;
        };
        credential.helper = "!${pkgs.gh}/bin/gh auth git-credential";
      };
    };
    ssh.extraConfig = ''
      Host *
        UserKnownHostsFile ~/.ssh/known_hosts
        SetEnv TERM=xterm-256color
    '';
  };

  users.users.${username} = {
    isNormalUser = true;
    description = userFullName;
    extraGroups = [ "wheel" ];
  };
}
