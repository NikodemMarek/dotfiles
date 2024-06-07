{
  inputs,
  config,
  hostname,
  username,
  ...
}: {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../${hostname}/secrets.yaml;
  };

  sops.secrets = {
    "users/${username}/ssh_ed25519_priv" = {};
    "config/openai_api_key" = {};
  };

  home.sessionVariables = {
    OPENAI_API_KEY = builtins.readFile /run/secrets/config/openai_api_key;
  };
}
