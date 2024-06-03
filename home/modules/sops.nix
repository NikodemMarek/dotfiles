{
  config,
  hostname,
  username,
  ...
}: {
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets.yaml;
  };

  sops.secrets = {
    "${hostname}/users/${username}/openai_api_key" = {};
  };

  home.sessionVariables = {
    OPENAI_API_KEY = builtins.readFile /run/secrets/${hostname}/users/${username}/openai_api_key;
  };
}
