{
  imports = [];

  sops.secrets = {
    "host_ssh_ed25519_priv" = {};
    "users/maintenance/password" = {
      neededForUsers = true;
    };
  };
}
