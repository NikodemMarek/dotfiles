{
  imports = [
    ../../secrets/networks.nix
    ../../secrets/api-keys.nix
  ];

  sops.secrets = {};
}
