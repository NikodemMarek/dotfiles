{ config, pkgs, lib, ... }: {
  home.packages = with pkgs; [
    # general
    tree-sitter
    ripgrep
    fd

    # copilot
    nodejs_16

    # ascii image viewer
    ascii-image-converter

    ## LSP
    # go
    go
    gopls

    # rust
    rustup # Use `rustup component add rust-analyzer` to get lsp

    # lua
    lua-language-server
    stylua
    # luajitPackages.luacheck

    # web dev
    # nodePackages_latest.svelte-check
    deno

    ccls
    # vimPlugins.nvim-jdtls

    # typst
    typst-lsp

    # nix
    nixd
    nixpkgs-fmt
  ];

  programs.neovim.enable = true;

  xdg.configFile.nvim = {
    source = ./config;
    recursive = true;
  };
}
