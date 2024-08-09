{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        name = "markdown";
        src = pkgs.fetchFromGitHub {
          owner = "MeanderingProgrammer";
          repo = "markdown.nvim";
          rev = "4d8b6032b659a45582089de8bcd839f8ccc4161d";
          hash = "sha256-yYB7qgtF4QIOEKqwxfjx2XaqHie+bfQmaYZV+fJOjk0=";
        };
      })
    ];
    extraConfigLua = ''
      require('render-markdown').setup({})
    '';
  };
}
