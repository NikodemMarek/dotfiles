{pkgs ? import <nixpkgs> {}, ...}: let
  aliases = [
    {
      name = "host-switch";
      command = ''
        git add --all
        nh os switch . -- --impure
      '';
      description = "switch host config";
    }
    {
      name = "host-update";
      command = "nh os switch . --update";
      description = "update host config";
    }
    {
      name = "ssh-new-user-key";
      command = ''
        ssh-keygen -f ./host/$1/user_$2_ssh_id_ed25519 -t ed25519 -C $2@$1

        printf "\nage key:\n"
        ssh-to-age < ./host/$1/user_$2_ssh_id_ed25519.pub
      '';
      description = "[host user] create a new user key";
    }
    {
      name = "ssh-new-host-key";
      command = ''
        ssh-keygen -f ./host/$1/ssh_host_ed25519_key -t ed25519 -C root@$1

        printf "\nadd this key to .sops.yaml\n"
        ssh-to-age < ./host/$1/ssh_host_ed25519_key.pub
        printf "\nand run sops-update-keys\n"
      '';
      description = "[host] create a new host key";
    }
    {
      name = "sops";
      command = "sops";
      description = "[file] update secrets";
    }
    {
      name = "sops-mkpasswd";
      command = "echo \"$1\" | mkpasswd -s";
      description = "[password] generate password";
    }
    {
      name = "sops-updatekeys";
      command = "sops updatekeys";
      description = "[file] update secrets keys";
    }
    {
      name = "build";
      command = "nix build .#$1";
      description = "[package] build package";
    }
    {
      name = "install-remote";
      command = ''
        if [ ! -f ./host/$1/ssh_host_ed25519_key ]; then
          echo "missing host key ./host/$1/ssh_host_ed25519_key"
          exit 1
        fi

        temp=$(mktemp -d)

        cleanup() {
          rm -rf "$temp"
        }
        trap cleanup EXIT

        install -d -m755 "$temp/persist/data/etc/ssh"

        cat ./host/$1/ssh_host_ed25519_key > "$temp/persist/data/etc/ssh/ssh_host_ed25519_key"

        chmod 600 "$temp/persist/data/etc/ssh/ssh_host_ed25519_key"

        nixos-anywhere --extra-files "$temp" --flake .#$1 $2 --option pure-eval false
      '';
      description = "[host user@ip] install on remote host";
    }
  ];
in {
  default = pkgs.mkShell {
    buildInputs =
      [pkgs.nh pkgs.ssh-to-age pkgs.sops pkgs.nixos-anywhere pkgs.disko pkgs.home-manager pkgs.nixos-generators]
      ++ (map (alias: pkgs.writeShellScriptBin alias.name alias.command) aliases);
    shellHook = ''
      printf "\e[33m
      ${builtins.concatStringsSep "\n" (map (alias: "\\e[1m${alias.name}\\e[0m\\e[33m \t\t -> ${alias.description}") aliases)}
      \e[0m"
    '';
  };
}
