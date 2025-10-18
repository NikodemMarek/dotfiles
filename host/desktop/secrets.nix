{
  imports = [
    ../../secrets/networks.nix
    ../../secrets/api-keys.nix
  ];

  sops.secrets = {
    "users/maintenance/password" = {
      neededForUsers = true;
    };

    "wireguard/server_tunnel_private_key" = {
      owner = "systemd-network";
    };
  };
}
