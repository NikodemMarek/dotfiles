{ config, pkgs, lib, ... }: {
  extraPkgs = [
    "tree-sitter"
    "ripgrep"
    "fd"

    # Copilot
    "nodejs_16"

    # LSP
    "go" "gopls"
    "rustup" # Use rustup component add rust-analyzer to get lsp
    "deno"
    "lua-language-server" "stylua"
    # "nodePackages_latest.svelte-check"
    "ccls"
    "typst-lsp"
  ];

  module = { ... }: {
    programs.neovim.enable = true;

    xdg.configFile.nvim = {
      source = ./config;
      recursive = true;
    };
  };
}
