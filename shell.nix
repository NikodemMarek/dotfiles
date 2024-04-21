{pkgs ? import <nixpkgs> {}}: let
  alias-sops-update = pkgs.writeShellScriptBin "sops-update" ''sops secrets.yaml'';
in
  pkgs.mkShell {
    buildInputs = with pkgs;
      [
        sops
      ]
      ++ [alias-sops-update];
    shellHook = ''
      printf "\e[33m
        \e[1msops-update\e[0m\e[33m  -> to run
      \e[0m"
    '';
  }
