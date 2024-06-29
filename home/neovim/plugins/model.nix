{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        name = "model";
        src = pkgs.fetchFromGitHub {
          owner = "gsuuon";
          repo = "model.nvim";
          rev = "42b09083bfd88f45a0fdd60d4c29de3a8bcb79b5";
          hash = "sha256-HtUiC2OGbeyEkB3dMwBeSfway368jNFg5d7jaPkE6T8=";
        };
      })
    ];
    extraConfigLua = "require('model').setup({})";
    keymaps = [
      {
        mode = "n";
        key = "<leader>aa";
        action = "<cmd>Model openai:gpt4-code<cr>";
        options.desc = "Generate code with GPT-4";
      }
    ];
  };
}
