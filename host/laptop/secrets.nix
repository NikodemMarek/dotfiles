{
  imports = [
    ../../secrets/api-keys.nix
    ../../secrets/clipboard-sync.nix
  ];

  sops.secrets = {
    "users/nikodem/ssh_id_ed25519" = {};
  };
}
