{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        name = "overseer";
        src = pkgs.fetchFromGitHub {
          owner = "stevearc";
          repo = "overseer.nvim";
          rev = "master";
          hash = "sha256-T5sRHOU+voBs4b7GKN2+undVd5rXOhuaGooyjITJrNw=";
        };
      })
    ];
    extraConfigLua = "require('overseer').setup({})";
  };
}
