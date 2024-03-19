{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        name = "hbac";
        src = pkgs.fetchFromGitHub {
          owner = "axkirillov";
          repo = "hbac.nvim";
          rev = "main";
          hash = "sha256-7+e+p+0zMHPJjpnKNkL7QQHZJGQ1DFZ6fsofcsVNXaY=";
        };
      })
    ];
    extraConfigLua = "require('hbac').setup({})";
  };
}
