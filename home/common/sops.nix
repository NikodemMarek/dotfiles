{
  inputs,
  config,
  ...
}: {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../setups/${config.settings.hostname}/secrets.yaml;
  };

  sops.secrets = {
    "users/${config.home.username}/ssh_ed25519_priv" = {};
    "config/openai_api_key" = {};
  };

  home.sessionVariables = let
    # FIXME: Temporary solution that only works if secrets are already present on the host.
    readIfExists = path:
      if builtins.pathExists path
      then builtins.readFile path
      else "";
  in {
    OPENAI_API_KEY = readIfExists config.sops.secrets."config/openai_api_key".path;
  };
}
