{pkgs ? import <nixpkgs> {}}: let
  alias-host-switch = pkgs.writeShellScriptBin "host-switch" ''git add --all ; nh os switch .'';
  alias-host-update = pkgs.writeShellScriptBin "host-update" ''nh os switch . --update'';

  alias-sops-update = pkgs.writeShellScriptBin "sops-update" ''sops secrets.yaml'';
  alias-sops-mkpasswd = pkgs.writeShellScriptBin "sops-mkpasswd" ''echo "$1" | mkpasswd -s'';
  alias-sops-get-key = pkgs.writeShellScriptBin "get-key" ''ssh-keyscan $1 | ssh-to-age'';
  alias-sops-update-keys = pkgs.writeShellScriptBin "sops-update-keys" ''sops updatekeys secrets.yaml'';

  alias-build = pkgs.writeShellScriptBin "build" ''nix build .#$1'';

  alias-install-remote = pkgs.writeShellScriptBin "install-remote" ''nixos-anywhere --copy-host-keys --flake .#$1 $2'';
in
  pkgs.mkShell {
    buildInputs =
      [pkgs.nh pkgs.sops]
      ++ [alias-host-switch alias-host-update alias-sops-update alias-sops-mkpasswd alias-sops-get-key alias-sops-update-keys alias-build alias-install-remote];
    shellHook = ''
      printf "\e[33m
        \e[1mhost-switch\e[0m\e[33m -> switch host config
        \e[1mhost-update\e[0m\e[33m -> update host config

        \e[1msops-update\e[0m\e[33m              -> update secrets.yaml
        \e[1msops-mkpasswd <password>\e[0m\e[33m -> generate password
        \e[1mget-key <host>\e[0m\e[33m           -> get host key
        \e[1msops-update-keys\e[0m\e[33m         -> update secrets.yaml keys

        \e[1mbuild <name>\e[0m\e[33m -> build package

        \e[1minstall-remote <name> <host>\e[0m\e[33m -> install on remote host
      \e[0m"
    '';
  }
