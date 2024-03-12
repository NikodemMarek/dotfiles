{
  imports = [
    ./options.nix
    ./keymaps.nix
    ./lsp.nix

    ./plugins/telescope.nix
    ./plugins/mini.nix
    ./plugins/comment-nvim.nix
    ./plugins/overseer.nix

    ./plugins/oil.nix
    ./plugins/auto-session.nix
    ./plugins/stay-centered.nix
    ./plugins/toggleterm.nix
    ./plugins/dressing.nix
    ./plugins/notify.nix

    ./plugins/which-key.nix
    ./plugins/rainbow-delimiters.nix
    ./plugins/bufferline.nix
    ./plugins/lualine.nix
    ./plugins/cursorline.nix

    ./plugins/treesitter.nix
    ./plugins/none-ls.nix
    ./plugins/nvim-cmp.nix
    ./plugins/luasnip.nix
    ./plugins/dap.nix
    ./plugins/rustaceanvim.nix
    ./plugins/crates-nvim.nix
    ./plugins/nvim-jdtls.nix

    ./plugins/wtf.nix
    ./plugins/copilot.nix
    ./plugins/model.nix

    ./plugins/gitsigns.nix
    ./plugins/gitui.nix
  ];

  programs = {
    nixvim = {
      enable = true;
      colorschemes.catppuccin.enable = true;
      globals.mapleader = " ";
      clipboard = {
        providers.wl-copy.enable = true;
        register = "unnamedplus";
      };
    };

    ripgrep.enable = true;
    neovim.defaultEditor = true;
  };

  home.shellAliases = {
    n = "nvim";
  };
}
