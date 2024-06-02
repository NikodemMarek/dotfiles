{pkgs ? import <nixpkgs> {}}: let
  alias-host-switch = pkgs.writeShellScriptBin "host-switch" ''git add --all ; nh os switch .'';
  alias-host-update = pkgs.writeShellScriptBin "host-update" ''nh os switch . --update'';

  alias-sops-update = pkgs.writeShellScriptBin "sops-update" ''sops secrets.yaml'';
  alias-sops-mkpasswd = pkgs.writeShellScriptBin "sops-mkpasswd" ''echo "$1" | mkpasswd -s'';

  alias-build = pkgs.writeShellScriptBin "build" ''nix build .#$1'';
in
  pkgs.mkShell {
    buildInputs =
      [pkgs.nh pkgs.sops]
      ++ [alias-host-switch alias-host-update alias-sops-update alias-build alias-sops-mkpasswd];
    shellHook = ''
      printf "\e[33m
        \e[1mhost-switch\e[0m\e[33m -> switch host config
        \e[1mhost-update\e[0m\e[33m -> update host config

        \e[1msops-update\e[0m\e[33m              -> update secrets.yaml
        \e[1msops-mkpasswd <password>\e[0m\e[33m -> generate password

        \e[1mbuild <name>\e[0m\e[33m -> build package
      \e[0m"
    '';
  }
