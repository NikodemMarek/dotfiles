{ config, pkgs, lib, settings, ... }: {
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
    ./plugins/rust-tools.nix
    ./plugins/luasnip.nix
    ./plugins/gitsigns.nix
  ];

  programs.neovim.defaultEditor = true;
  programs.nixvim = {
    enable = true;

    colorschemes.catppuccin.enable = true;

    globals.mapleader = " ";

    clipboard = {
        providers.wl-copy.enable = true;
        register = "unnamedplus";
    };
  };

  programs.ripgrep.enable = true;

  home.shellAliases = {
    n = "nvim";
  };
}
