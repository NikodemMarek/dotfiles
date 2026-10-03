{
  secrets = {
    host_ssh_ed25519_priv = {};
    # Hash with `mkpasswd`
    users_nikodem_password = {
      neededForUsers = true;
    };
    users_nikodem_ssh_id_ed25519 = {
      owner = "nikodem";
      group = "users";
      path = "/home/nikodem/.ssh/id_ed25519";
    };
  };
}
