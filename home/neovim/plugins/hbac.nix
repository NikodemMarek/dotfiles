{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        name = "hbac";
        src = pkgs.fetchFromGitHub {
          owner = "axkirillov";
          repo = "hbac.nvim";
          rev = "main";
          hash = "sha256-JDMP7Nmh5S7eDLd2sJMYrEDZ9W1J/iAtJ8Zuo0rfzEE=";
        };
      })
    ];
    extraConfigLua = "require('hbac').setup({})";
  };
}
