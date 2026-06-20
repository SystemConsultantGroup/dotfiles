{
  pkgs,
  username,
  gitUserName,
  gitUserEmail,
  ...
}:
{
  home-manager.users.${username}.programs.git = {
    enable = true;
    settings = {
      user = {
        name = gitUserName;
        email = gitUserEmail;
      };
      credential = {
        helper = "!${pkgs.gh}/bin/gh auth git-credential";
      };
    };
  };
}
