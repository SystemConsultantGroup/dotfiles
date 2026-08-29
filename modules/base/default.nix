{
  pkgs,
  username,
  userFullName,
  gitUserName,
  gitUserEmail,
  ...
}:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  security.sudo.wheelNeedsPassword = false;

  imports = [
    ./pi.nix
  ];

  networking = {
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
      "1.0.0.1"
      "8.8.4.4"
    ];
    networkmanager.enable = true;
    nftables.enable = true;
    firewall.enable = false;
  };

  nixpkgs.config.allowUnfree = true;

  environment = {
    systemPackages = [
      pkgs.nh
      pkgs.gh
      pkgs.nix-search-cli
      pkgs.zip
      pkgs.unzip
      pkgs.ripgrep
      pkgs.jq
      pkgs.fd
      pkgs.killall
      pkgs.uv
      pkgs.nodejs
      pkgs.pnpm
      pkgs.devenv
      pkgs.abduco
    ];

    variables.SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    sessionVariables.NH_OS_FLAKE = "/home/${username}/dotfiles";
  };

  programs = {
    nix-ld = {
      enable = true;
      libraries = [
        pkgs.stdenv.cc.cc
        pkgs.zlib
      ];
    };

    bash = {
      promptInit = ''
        export PS1="\[\033[1;32m\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\] "
      '';

      interactiveShellInit = ''
        export PATH="$HOME/.local/bin:$PATH"

        if command -v gh &>/dev/null; then
          export GITHUB_TOKEN="$(gh auth token 2>/dev/null)"
        fi

        if command -v devenv &>/dev/null; then
          eval "$(devenv hook bash)"
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

    ssh = {
      extraConfig = ''
        Host *
          # alacritty's terminfo is missing on most remote hosts, so send a TERM that exists everywhere
          UserKnownHostsFile ~/.ssh/known_hosts
          SetEnv TERM=xterm-256color
      '';
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };

  users.users.${username} = {
    isNormalUser = true;
    description = userFullName;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDTLmX82sXKztx9xDV+Ak6ttg5h99PUkoojbPXIOjy7cVDhEwxe/BwtVVQPzbBpUKYe2x3yiDvi5Djuk3ubX87WEmcCrD/d41wkHRh3GD4W+A0l5X9yC8bUpj3hNRZ9rul23kCHN4kRA9e6TTAEsGM8EdWLcLuhm38VdFbGvupTESB3EReS/u0Ti85YCljRpW8rq1Hd2duC3xbGxuti6cTI8uELVHsPNRSQ+Dv6Sb9pniPvd6weOQ45OygVro9sE97XESkcDheTgWLNlXb0EkRhmHE6KmMhfKHLHDPTXIiXyFMt02S7Gr9V+1B69fPLXaz9UpZifSZsnUsA1aD8P+jD"
    ];
    extraGroups = [
      "networkmanager"
      "wheel"
      "kvm"
      "video"
      "render"
    ];
  };
}
