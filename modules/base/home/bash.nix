{ username, ... }:
{
  home-manager.users.${username}.programs = {
    bash = {
      enable = true;
      bashrcExtra = ''
        export PS1="\[\033[1;32m\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\] "

        export PATH="$HOME/.local/bin:$PATH"

        alias pi="pnpx @earendil-works/pi-coding-agent"
        alias oc="pnpx opencode-ai"

        if command -v gh &>/dev/null; then
          export GITHUB_TOKEN="$(gh auth token 2>/dev/null)"
        fi

        if command -v devenv &>/dev/null; then
          eval "$(devenv hook bash)"
        fi
      '';
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
