{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        name = "dressing";
        src = pkgs.fetchFromGitHub {
          owner = "stevearc";
          repo = "dressing.nvim";
          rev = "6f212262061a2120e42da0d1e87326e8a41c0478";
          hash = "sha256-Y+ABLhb3GIaPKOuQzkxsZsTo1WfgURAYVioP/eCSp/Y=";
        };
      })
    ];
    extraConfigLua = "require('dressing').setup({})";
  };
}
