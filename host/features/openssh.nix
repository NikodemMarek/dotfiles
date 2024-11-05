{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };

    hostKeys = [
      {
        path = "/persist/data/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };
}
