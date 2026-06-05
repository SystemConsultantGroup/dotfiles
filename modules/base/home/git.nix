{
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
    };
  };
}
