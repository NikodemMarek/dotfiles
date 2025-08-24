{
  inputs,
  config,
  ...
}: let
  # FIXME: Temporary solution that only works if secrets are already present on the host.
  readIfExists = path:
    if builtins.pathExists path
    then builtins.readFile path
    else "";
  secretExists = secret:
    builtins.hasAttr secret config.sops.secrets;
  readSecretIfExists = secret:
    if secretExists secret
    then readIfExists config.sops.secrets.${secret}.path
    else "";
in {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  };

  home.sessionVariables = {
    OPENAI_API_KEY = readSecretIfExists "api_keys/openai";
  };
}
