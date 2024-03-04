{
  imports = [
    ./options.nix
    ./keymaps.nix
    ./lsp.nix

    ./plugins/treesitter.nix
    ./plugins/which-key.nix
    ./plugins/telescope.nix
    ./plugins/oil.nix
    ./plugins/stay-centered.nix
    ./plugins/bufferline.nix
    ./plugins/auto-session.nix
    ./plugins/nvim-cmp.nix
    ./plugins/copilot.nix
    ./plugins/comment-nvim.nix
    ./plugins/lualine.nix
    ./plugins/cursorline.nix
    ./plugins/mini.nix
    ./plugins/crates-nvim.nix
    ./plugins/rustaceanvim.nix
    ./plugins/luasnip.nix
    ./plugins/gitsigns.nix
    ./plugins/dap.nix
    ./plugins/wtf.nix
    ./plugins/rainbow-delimiters.nix
    ./plugins/toggleterm.nix
    ./plugins/none-ls.nix
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
