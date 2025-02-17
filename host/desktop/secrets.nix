{
  imports = [
    ../../secrets/networks.nix
    ../../secrets/api-keys.nix
  ];

  sops.secrets = {
    "users/nikodem/ssh_id_ed25519" = {};
  };
}
