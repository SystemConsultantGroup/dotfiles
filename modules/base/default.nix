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

  programs = {
    nix-ld = {
      enable = true;
      libraries = [
        pkgs.stdenv.cc.cc
        pkgs.zlib
      ];
    };

    bash.interactiveShellInit = ''
      export PS1="\[\033[1;32m\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\] "

      export PATH="$HOME/.local/bin:$PATH"

      alias pi="pnpx --allow-build=@google/genai --allow-build=protobufjs @earendil-works/pi-coding-agent@latest"
      alias oc="pnpx opencode-ai@latest"
      alias claude="pnpx @anthropic-ai/claude-code@latest"

      if command -v gh &>/dev/null; then
        export GITHUB_TOKEN="$(gh auth token 2>/dev/null)"
      fi

      if command -v devenv &>/dev/null; then
        eval "$(devenv hook bash)"
      fi
    '';

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
    extraGroups = [
      "networkmanager"
      "wheel"
      "kvm"
      "video"
      "render"
    ];
    packages = [
      pkgs.nh
      pkgs.gh
      pkgs.nix-search-cli
      pkgs.zip
      pkgs.unzip
      pkgs.ripgrep
      pkgs.jq
      pkgs.bat
      pkgs.fd
      pkgs.fzf
      pkgs.killall
      pkgs.uv
      pkgs.nodejs
      pkgs.pnpm
      pkgs.devenv
    ];
  };

  environment.variables.SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
  environment.sessionVariables.NH_OS_FLAKE = "/home/aperso/dotfiles";
}
