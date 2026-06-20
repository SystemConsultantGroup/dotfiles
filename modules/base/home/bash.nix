{ username, ... }:
{
  home-manager.users.${username}.programs = {
    bash = {
      enable = true;
      bashrcExtra = ''
        export PS1="\[\033[1;32m\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\] "
        alias opencode="bunx opencode-ai"
        # Set GITHUB_TOKEN from gh auth token (local read, no network)
        if command -v gh &>/dev/null; then
          export GITHUB_TOKEN="$(gh auth token 2>/dev/null)"
        fi
      '';
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
