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
  };
}
