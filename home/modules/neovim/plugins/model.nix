{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        name = "model";
        src = pkgs.fetchFromGitHub {
          owner = "gsuuon";
          repo = "model.nvim";
          rev = "main";
          hash = "sha256-/OsUlBeRFdZL1x8bJYt8ZbDOYWPM+UJLvQvI7EObyn8=";
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
