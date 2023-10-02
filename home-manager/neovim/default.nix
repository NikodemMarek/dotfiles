{ config, pkgs, lib, ... }: {
  extraPkgs = [
    "tree-sitter"
    "ripgrep"
    "fd"

    # Copilot
    "nodejs_16"

    # LSP
    "go"
    "gopls"
    "deno"
    "stylua"
    "lua-language-server"
  ];

  module = { ... }: {
    programs.neovim.enable = true;

    xdg.configFile.nvim = {
      source = ./config;
      recursive = true;
    };
  };
}
