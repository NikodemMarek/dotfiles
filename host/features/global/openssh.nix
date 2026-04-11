{config, ...}: {
  programs.ssh.startAgent = true;
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };

    hostKeys = [
      {
        path = config.sops.secrets."host_ssh_ed25519_priv".path;
        type = "ed25519";
      }
    ];
  };
}
