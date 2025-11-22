{
  imports = [
    ../../secrets/networks.nix
    ../../secrets/api-keys.nix
  ];

  sops.secrets = {
    "users/maintenance/password" = {
      neededForUsers = true;
    };
    "users/music/password" = {
      neededForUsers = true;
    };

    "wireguard/server_tunnel_private_key" = {
      owner = "systemd-network";
    };

    "youtube/cookies.txt" = {
      sopsFile = ./cookies.txt;
      format = "binary";
      owner = "music";
      mode = "600";
    };
  };
}
