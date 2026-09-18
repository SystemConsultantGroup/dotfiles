_: {
  services.openssh = {
    enable = true;
    settings = {
      # Password access remains necessary until authorized keys are configured.
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
    };
  };
}
