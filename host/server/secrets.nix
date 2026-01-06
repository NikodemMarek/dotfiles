{
  sops.secrets = {
    "host_ssh_ed25519_priv" = {};
    "users/maintenance/password" = {
      neededForUsers = true;
    };

    "matrix/registration_token" = {};

    "wireguard/private_key" = {
      owner = "systemd-network";
    };
  };
}
