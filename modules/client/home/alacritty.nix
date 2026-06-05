{ username, ... }:
{
  home-manager.users.${username}.programs.alacritty = {
    enable = true;
    settings = {
      window.padding = {
        x = 8;
        y = 10;
      };
    };
  };
}
