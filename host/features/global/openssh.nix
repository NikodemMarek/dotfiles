{config, ...}: let
  hostKey = config.secrets.host_ssh_ed25519_priv.path;
in {
  secretsRequired.host_ssh_ed25519_priv = {};

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
        path = hostKey;
        type = "ed25519";
      }
    ];
  };

  environment.etc = {
    "ssh/ssh_host_ed25519_key".source = hostKey;
    "ssh/ssh_host_ed25519_key.pub".source = ../../${config.networking.hostName}/ssh_host_ed25519_key.pub;
  };
}
