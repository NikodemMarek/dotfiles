{config, ...}: {
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };

    hostKeys = [
      {
        path =
          if config.persist.enable
          then "/persist/data/etc/ssh/ssh_host_ed25519_key"
          else "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [22];
}
