{config, ...}: {
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets.yaml;
  };

  sops.secrets = {
    "configs/openai_api_key" = {};
  };

  home.sessionVariables = {
    OPENAI_API_KEY = builtins.readFile /run/secrets/configs/openai_api_key;
  };
}
