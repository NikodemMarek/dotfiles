{
  pkgs,
  lib,
  host-config,
  config,
  ...
}: let
  inherit (lib) optionalString elemAt;
in {
  xdg.configFile."fabric/.env".text = let
    olmCfg = host-config.services.ollama;
  in ''
    PATTERNS_LOADER_GIT_REPO_URL=https://github.com/danielmiessler/fabric.git
    PATTERNS_LOADER_GIT_REPO_PATTERNS_FOLDER=patterns

    ${optionalString olmCfg.enable "DEFAULT_VENDOR=Ollama"}

    ${optionalString olmCfg.enable "OLLAMA_API_URL=http://${olmCfg.host}:${toString olmCfg.port}"}
    ${optionalString (builtins.length olmCfg.loadModels > 0) "DEFAULT_MODEL=${elemAt olmCfg.loadModels 0}"}

    ${optionalString (builtins.hasAttr "api_keys/youtube" config.sops.secrets && builtins.pathExists config.sops.secrets."api_keys/youtube".path) "YOUTUBE_API_KEY=${builtins.readFile config.sops.secrets."api_keys/youtube".path}"}
  '';

  home = {
    packages = with pkgs; [
      fabric-ai
    ];
    persistence."/persist/generated/${config.home.homeDirectory}".directories = [
      ".config/fabric"
    ];
  };
}
