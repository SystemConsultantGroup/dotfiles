{ username, ... }:
{
  home-manager.users.${username}.services.flameshot = {
    enable = true;
    settings = {
      General = {
        disabledGrimWarning = true;
        useGrimAdapter = true;
      };
    };
  };
}
