{pkgs ? import <nixpkgs> {}}: let
  alias-host-switch = pkgs.writeShellScriptBin "host-switch" ''git add --all ; nh os switch .'';
  alias-host-update = pkgs.writeShellScriptBin "host-update" ''nh os switch . --update'';

  alias-sops-update = pkgs.writeShellScriptBin "sops-update" ''sops secrets.yaml'';

  alial-build = pkgs.writeShellScriptBin "build" ''nix build .#$1'';

  alias-install-remote = pkgs.writeShellScriptBin "install-remote" ''
    nix run github:nix-community/nixos-anywhere -- --flake '.#$1' nixos@$2
  '';
in
  pkgs.mkShell {
    buildInputs =
      [pkgs.nh pkgs.sops]
      ++ [alias-host-switch alias-host-update alias-sops-update alial-build alias-install-remote];
    shellHook = ''
      printf "\e[33m
        \e[1mhost-switch\e[0m\e[33m  -> switch host config
        \e[1mhost-update\e[0m\e[33m  -> update host config

        \e[1msops-update\e[0m\e[33m  -> update secrets.yaml

        \e[1mbuild <name>\e[0m\e[33m  -> build package

        \e[1minstall-remote <name> <host>\e[0m\e[33m  -> install on remote host
      \e[0m"
    '';
  }
