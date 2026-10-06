{pkgs ? import <nixpkgs> {}, ...}: let
  # Runs a command and answers deploy-rs's interactive sudo prompts with
  # SUDO_PASSWORD_<host>, asking on the terminal for hosts without one
  sudoExpect = pkgs.writeText "deploy-sudo.exp" ''
    set timeout -1
    foreach name [array names env SUDO_PASSWORD_*] {
      set password([string range $name 14 end]) $env($name)
      unset env($name)
    }

    spawn -noecho {*}$argv
    expect {
      -re {\(sudo for ([^)]+)\) Password: } {
        set host $expect_out(1,string)
        if {[info exists password($host)]} {
          send -- "$password($host)\r"
        } else {
          send_user "(sudo for $host) Password: "
          stty -echo
          expect_user -re "(.*)\n"
          stty echo
          send_user "\n"
          send -- "$expect_out(1,string)\r"
        }
        exp_continue
      }
      eof
    }

    lassign [wait] pid spawn_id os_error status
    exit $status
  '';

  aliases = [
    {
      name = "secrets-build";
      command = ''
        set -euo pipefail

        if [ "$#" -lt 2 ]; then
          echo "usage: secrets-build outdir host..."
          exit 1
        fi

        outdir=$1
        shift
        mkdir -p "$outdir"
        chmod 700 "$outdir"

        if [ -z "''${BW_SESSION:-}" ]; then BW_SESSION=$(bw unlock --raw); unlocked=1; fi
        export BW_SESSION
        trap 'if [ -n "''${unlocked:-}" ]; then bw lock > /dev/null; fi' EXIT
        bw sync > /dev/null

        for h in "$@"; do
          names=$(nix eval --json ".#nixosConfigurations.$h.config.secrets" --apply builtins.attrNames)

          # plaintext only ever lives in memory and pipes, never touches the disk
          json=$(secretspec export --profile "$h" --format json \
            | jq --argjson names "$names" '
                with_entries(.key |= ascii_downcase)
                | if ($names - keys) != [] then error("missing in bitwarden: \($names - keys)") else . end
                | with_entries(select(.key as $k | $names | any(. == $k)))
                | ([to_entries[] | select(.value == null or .value == "") | .key]) as $e | if $e != [] then error("empty in bitwarden: \($e)") else . end')

          # ssh private keys must match their public halves in the repo, a
          # rerolled key must come with an updated .pub
          for k in $(printf '%s' "$json" | jq -r 'keys[] | select(. == "host_ssh_ed25519_priv" or test("^users_.+_ssh_id_ed25519$"))'); do
            case $k in
              host_ssh_ed25519_priv) file=host/$h/ssh_host_ed25519_key.pub ;;
              *) user=''${k#users_}; file=host/$h/user_''${user%_ssh_id_ed25519}_ssh_id_ed25519.pub ;;
            esac
            pub=$(printf '%s' "$json" | jq -r --arg k "$k" '.[$k]' | ssh-keygen -y -f /dev/stdin | cut -d' ' -f1-2)
            if [ "$pub" != "$(cut -d' ' -f1-2 "$file" 2> /dev/null)" ]; then
              echo "$h: $k in bitwarden does not match $file" >&2
              exit 1
            fi
          done

          # the host key is also the host's sops identity
          have=$(ssh-to-age < "host/$h/ssh_host_ed25519_key.pub")
          want=$(sed -n "s/.*&$h \(age1[0-9a-z]*\).*/\1/p" .sops.yaml)
          if [ "$have" != "$want" ]; then
            echo "$h: host key is $have, but .sops.yaml has ''${want:-nothing}" >&2
            exit 1
          fi

          # passwords are stored in plain text, hashedPasswordFile needs a hash
          for k in $(printf '%s' "$json" | jq -r 'keys[] | select(endswith("_password"))'); do
            hash=$(printf '%s' "$json" | jq -r --arg k "$k" '.[$k]' | mkpasswd -s)
            json=$(printf '%s' "$json" | HASH=$hash jq --arg k "$k" '.[$k] = env.HASH')
          done

          printf '%s' "$json" \
            | sops encrypt --input-type json --output-type yaml \
                --filename-override "host/$h/secrets.yaml" /dev/stdin > "$outdir/.$h.yaml.tmp"
          mv "$outdir/.$h.yaml.tmp" "$outdir/$h.yaml"
        done
      '';
      description = "[outdir host...] build encrypted sops files from bitwarden";
    }
    {
      name = "host-switch";
      command = ''
        set -euo pipefail

        tmp=$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/secrets.XXXXXX")

        # unlock once, secrets-build and the sudo password below reuse the session
        if [ -z "''${BW_SESSION:-}" ]; then BW_SESSION=$(bw unlock --raw); unlocked=1; fi
        export BW_SESSION
        trap 'rm -rf "$tmp"; if [ -n "''${unlocked:-}" ]; then bw lock > /dev/null; fi' EXIT

        host=$(hostname)
        secrets-build "$tmp" "$host"

        # the login password is in bitwarden too, use it to unlock sudo; if it
        # doesn't match (yet), sudo below just prompts as usual
        if password=$(secretspec get --profile "$host" "USERS_''${USER^^}_PASSWORD" 2> /dev/null); then
          printf '%s\n' "$password" | sudo -S -p "" -v 2> /dev/null || true
        fi
        unset password

        sudo nixos-rebuild "''${@:-switch}" --flake ".#$host" --override-input secrets "path:$tmp"
      '';
      description = "[nixos-rebuild action] rebuild this host (default: switch)";
    }
    {
      name = "host-deploy";
      command = ''
        set -euo pipefail

        if [ "$#" -lt 1 ]; then
          echo "usage: host-deploy node..."
          exit 1
        fi

        tmp=$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/secrets.XXXXXX")

        # unlock once, secrets-build and the sudo passwords below reuse the session
        if [ -z "''${BW_SESSION:-}" ]; then BW_SESSION=$(bw unlock --raw); unlocked=1; fi
        export BW_SESSION
        trap 'rm -rf "$tmp"; if [ -n "''${unlocked:-}" ]; then bw lock > /dev/null; fi' EXIT

        secrets-build "$tmp" "$@"

        # refuse to deploy to a host whose ssh key differs from bitwarden
        for n in "$@"; do
          addr=$(nix eval --raw ".#deploy.nodes.$n.hostname")
          actual=$(ssh-keyscan -t ed25519 "$addr" 2> /dev/null | cut -d' ' -f2-3)
          if [ -z "$actual" ]; then
            echo "$n: could not read the host key of $addr" >&2
            exit 1
          fi
          if [ "$actual" != "$(cut -d' ' -f1-2 "host/$n/ssh_host_ed25519_key.pub")" ]; then
            echo "$n: host key on $addr does not match host/$n/ssh_host_ed25519_key.pub" >&2
            exit 1
          fi
        done

        # the ssh users' passwords are in bitwarden too, answer deploy-rs's sudo
        # prompts with them; hosts without one are asked on the terminal
        for n in "$@"; do
          user=$(nix eval --raw ".#deploy.nodes.$n.profiles.system.sshUser")
          if password=$(secretspec get --profile "$n" "USERS_''${user^^}_PASSWORD" 2> /dev/null); then
            export "SUDO_PASSWORD_$n=$password"
          fi
        done
        unset password

        # deploy-rs's flake check evaluates every host, but $tmp only holds the requested ones
        targets=()
        for n in "$@"; do targets+=(".#$n"); done
        expect ${sudoExpect} deploy --skip-checks --targets "''${targets[@]}" -- --override-input secrets "path:$tmp"
      '';
      description = "[node...] deploy config to remote hosts";
    }
    {
      name = "install-remote";
      command = ''
        set -euo pipefail

        if [ ! -f ./host/$1/ssh_host_ed25519_key ]; then
          echo "missing host key ./host/$1/ssh_host_ed25519_key"
          exit 1
        fi

        temp=$(mktemp -d)
        secrets=$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/secrets.XXXXXX")

        cleanup() {
          rm -rf "$temp" "$secrets"
        }
        trap cleanup EXIT

        secrets-build "$secrets" "$1"

        install -d -m755 "$temp/persist/data/etc/ssh"
        cat ./host/$1/ssh_host_ed25519_key > "$temp/persist/data/etc/ssh/ssh_host_ed25519_key"
        chmod 600 "$temp/persist/data/etc/ssh/ssh_host_ed25519_key"

        # only for zfs encrypted filesystems
        # install -d -m755 "$temp/persist/data/etc/zfs"
        # cat ./host/$1/disk.key > "$temp/persist/data/etc/zfs/disk.key"
        # chmod 600 "$temp/persist/data/etc/zfs/disk.key"

        # nixos-anywhere has no --override-input, so build locally and pass store paths
        toplevel=$(nix build --impure --no-link --print-out-paths \
          ".#nixosConfigurations.$1.config.system.build.toplevel" \
          --override-input secrets "path:$secrets")
        disko=$(nix build --impure --no-link --print-out-paths \
          ".#nixosConfigurations.$1.config.system.build.diskoScript" \
          --override-input secrets "path:$secrets")

        nixos-anywhere \
          --disk-encryption-keys /tmp/disk.key ./host/$1/disk.key \
          --extra-files "$temp" \
          --store-paths "$disko" "$toplevel" \
          $2
      '';
      description = "[host user@ip] install on remote host";
    }
    {
      name = "mkiso";
      command = "nixos-generate --format iso --configuration ./host/alp/default.nix -o result";
      description = "generate iso file";
    }
    {
      name = "writeiso";
      command = ''
        ISO=$(ls result/iso/*.iso)
        sudo dd if=$ISO of=$1 status=progress && sync
      '';
      description = "[/dev/XXX] write iso file to device";
    }
  ];
in {
  default = pkgs.mkShell {
    buildInputs =
      [pkgs.deploy-rs.deploy-rs pkgs.ssh-to-age pkgs.sops pkgs.nixos-anywhere pkgs.disko pkgs.nixos-generators pkgs.bitwarden-cli pkgs.secretspec pkgs.jq pkgs.mkpasswd pkgs.expect]
      ++ (map (alias: pkgs.writeShellScriptBin alias.name alias.command) aliases);
    shellHook = ''
      printf "\e[33m
      ${builtins.concatStringsSep "\n" (map (alias: "\\e[1m${alias.name}\\e[0m\\e[33m \t\t -> ${alias.description}") aliases)}
      \e[0m"
    '';
  };
}
