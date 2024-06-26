{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        name = "dressing";
        src = pkgs.fetchFromGitHub {
          owner = "stevearc";
          repo = "dressing.nvim";
          rev = "master";
          hash = "sha256-Y+ABLhb3GIaPKOuQzkxsZsTo1WfgURAYVioP/eCSp/Y=";
        };
      })
    ];
    extraConfigLua = "require('dressing').setup({})";
  };
}
