{
  sops.secrets = let
    sopsFile = ./api-keys.yaml;
    format = "yaml";
  in {
    "api_keys/youtube" = {
      inherit sopsFile format;
    };
    "api_keys/openai" = {
      inherit sopsFile format;
    };
  };
}
