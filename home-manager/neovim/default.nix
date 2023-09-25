{ config, pkgs, lib, ... }: {
  extraPkgs = [
    "tree-sitter"
    "ripgrep"
    "fd"
  ];

  module = { ... }: {
    xdg.configFile.nvim = {
      source = ./config;
      recursive = true;
    };
  };
}
