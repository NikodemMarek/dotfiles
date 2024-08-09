{
  inputs,
  config,
  ...
}: {
  imports = [
    inputs.nixvim.homeManagerModules.nixvim

    ./options.nix
    ./keymaps.nix
    ./lsp.nix

    ./plugins/telescope.nix
    ./plugins/oil.nix
    ./plugins/mini.nix
    ./plugins/comment.nix
    ./plugins/overseer.nix
    ./plugins/toggleterm.nix

    ./plugins/auto-session.nix
    ./plugins/stay-centered.nix
    ./plugins/trailblazer.nix
    ./plugins/dressing.nix
    ./plugins/noice.nix
    ./plugins/hbac.nix
    ./plugins/autoread.nix
    ./plugins/bufdelete.nix

    ./plugins/which-key.nix
    ./plugins/rainbow-delimiters.nix
    ./plugins/lualine.nix
    ./plugins/cursorline.nix
    ./plugins/highlight.nix
    ./plugins/markdown.nix

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
    ./plugins/neogit.nix
  ];

  programs = {
    nixvim = {
      enable = true;
      defaultEditor = true;
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

  stylix.targets.nixvim.enable = false;

  home = {
    shellAliases = {
      n = "nvim";
    };
    persistence."/persist/home/${config.home.username}".directories = [
      ".local/share/nvim"

      ".npm"
      ".cargo"
      ".java"
      ".gradle"
      ".m2"
      ".android"
    ];
  };
}
