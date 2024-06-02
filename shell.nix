{pkgs ? import <nixpkgs> {}}: let
  aliases = [
    {
      name = "host-switch";
      command = ''
        git add --all
        nh os switch .
      '';
      description = "switch host config";
    }
    {
      name = "host-update";
      command = "nh os switch . --update";
      description = "update host config";
    }
    {
      name = "ssh-new-host-key";
      command = ''
        ssh-keygen -f ./host/$1/ssh_host_ed25519_key -t ed25519 -C root@$1
        ssh-keygen -f ./host/$1/ssh_host_rsa_key -t rsa -C root@$1

        printf "\nadd this key to .sops.yaml\n"
        ssh-to-age < ./host/$1/ssh_host_ed25519_key.pub
        printf "\nand run sops-update-keys\n"
      '';
      description = "[host] create a new host key";
    }
    {
      name = "sops-update";
      command = "sops secrets.yaml";
      description = "update secrets.yaml";
    }
    {
      name = "sops-mkpasswd";
      command = "echo \"$1\" | mkpasswd -s";
      description = "[password] generate password";
    }
    {
      name = "sops-update-keys";
      command = "sops updatekeys secrets.yaml";
      description = "update secrets.yaml keys";
    }
    {
      name = "build";
      command = "nix build .#$1";
      description = "[package] build package";
    }
    {
      name = "install-remote";
      command = ''
        temp=$(mktemp -d)

        cleanup() {
          rm -rf "$temp"
        }
        trap cleanup EXIT

        install -d -m755 "$temp/persist/etc/ssh"

        cat ./host/$1/ssh_host_ed25519_key > "$temp/persist/etc/ssh/ssh_host_ed25519_key"
        cat ./host/$1/ssh_host_rsa_key > "$temp/persist/etc/ssh/ssh_host_rsa_key"

        chmod 600 "$temp/persist/etc/ssh/ssh_host_ed25519_key"
        chmod 600 "$temp/persist/etc/ssh/ssh_host_rsa_key"

        nixos-anywhere --extra-files "$temp" --flake .#$1 $2
      '';
      description = "[host user@ip] install on remote host";
    }
  ];
in
  pkgs.mkShell {
    buildInputs =
      [pkgs.nh pkgs.ssh-to-age pkgs.sops pkgs.nixos-anywhere]
      ++ (map (alias: pkgs.writeShellScriptBin alias.name alias.command) aliases);
    shellHook = ''
      printf "\e[33m
      ${builtins.concatStringsSep "\n" (map (alias: "\\e[1m${alias.name}\\e[0m\\e[33m \t\t -> ${alias.description}") aliases)}
      \e[0m"
    '';
  }
