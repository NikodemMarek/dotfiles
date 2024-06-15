{
  pkgs,
  config,
  ...
}: {
  programs.nixvim.plugins = {
    nvim-jdtls = {
      enable = true;
      cmd = [
        "${pkgs.jdt-language-server}/bin/jdtls"
        "-data"
        "${config.home.homeDirectory}/.cache/jdtls/data"
        "-configuration"
        "${config.home.homeDirectory}/.cache/jdtls/configuration"
      ];
    };
  };
}
