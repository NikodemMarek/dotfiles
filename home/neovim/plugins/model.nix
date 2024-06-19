{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        name = "model";
        src = pkgs.fetchFromGitHub {
          owner = "gsuuon";
          repo = "model.nvim";
          rev = "main";
          hash = "sha256-uZu0WVRF7J1MASG/oVsfc78a8IdoL4lioH2GPn98vfU=";
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
