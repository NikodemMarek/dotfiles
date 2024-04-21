{pkgs ? import <nixpkgs> {}}: let
  alias-host-switch = pkgs.writeShellScriptBin "host-switch" ''git add --all ; nh os switch /dotfiles'';
  alias-host-update = pkgs.writeShellScriptBin "host-update" ''nh os switch /dotfiles --update'';
  alias-sops-update = pkgs.writeShellScriptBin "sops-update" ''sops secrets.yaml'';
in
  pkgs.mkShell {
    buildInputs = with pkgs;
      [
        nh
        sops
      ]
      ++ [alias-host-switch alias-host-update alias-sops-update];
    shellHook = ''
      printf "\e[33m
        \e[1mhost-switch\e[0m\e[33m  -> switch host config
        \e[1mhost-update\e[0m\e[33m  -> update host config

        \e[1msops-update\e[0m\e[33m  -> update secrets.yaml
      \e[0m"
    '';
  }
