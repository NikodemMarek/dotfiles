{
  pkgs,
  lib,
  host-config,
  ...
}: let
  olmCfg = host-config.services.ollama;
in {
  home.shellAliases = lib.mkIf (olmCfg.enable && builtins.length olmCfg.loadModels > 0) {
    olm = lib.getExe (pkgs.writeShellScriptBin "olm-alias"
      ''
        RES=$(OLLAMA_HOST=${olmCfg.host}:${toString olmCfg.port} ollama run ${lib.elemAt olmCfg.loadModels 0} \"$@\")
        echo $RES | ${lib.getExe pkgs.bat} -ppl md
        echo $RES | ${pkgs.wl-clipboard}/bin/wl-copy
      '');
    olc = "OLLAMA_HOST=${olmCfg.host}:${toString olmCfg.port} ollama run ${lib.elemAt olmCfg.loadModels 0}";
  };
}
