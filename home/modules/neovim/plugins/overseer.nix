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
    extraConfigLua = ''
      require("overseer").setup({
        strategy = "toggleterm",
      })
    '';
    keymaps = [
      {
        mode = "n";
        key = "<leader>rr";
        action = "<cmd>OverseerRun<cr>";
        options.desc = "Run overseer task";
      }
      {
        mode = "n";
        key = "<leader>rt";
        action = "<cmd>OverseerToggle<cr>";
        options.desc = "Run overseer toggle task list";
      }
      {
        mode = "n";
        key = "<leader>ra";
        action = "<cmd>OverseerTaskAction<cr>";
        options.desc = "Run overseer task actions";
      }
    ];
  };
}
