{
  imports = [
    ../../secrets/networks.nix
    ../../secrets/api-keys.nix
  ];

  sops.secrets = {
    "wireguard/server_tunnel_private_key" = {
      owner = "systemd-network";
    };
  };
}
