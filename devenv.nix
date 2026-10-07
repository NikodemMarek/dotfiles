{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
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

  # Sourced by the scripts below
  common = pkgs.writeText "common.sh" ''
    set -euo pipefail
    # also fail inside $(...), so a failing step in a function aborts the script
    shopt -s inherit_errexit

    # cleanups run in order on exit, a plain `trap` would replace earlier ones
    _cleanups=()
    trap 'for c in "''${_cleanups[@]}"; do eval "$c"; done' EXIT
    on_exit() { _cleanups+=("$1"); }

    # unlock once, nested scripts inherit BW_SESSION and skip this
    bw_unlock() {
      if [ -z "''${BW_SESSION:-}" ]; then
        BW_SESSION=$(bw unlock --raw)
        on_exit 'bw lock > /dev/null'
      fi
      export BW_SESSION
    }

    # [host...] builds encrypted secrets for the hosts into $secrets
    build_secrets() {
      secrets=$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/secrets.XXXXXX")
      on_exit "rm -rf '$secrets'"
      secrets-build "$secrets" "$@"
    }

    # [host user] login password from bitwarden, fails if there is none
    user_password() { secretspec get --profile "$1" "USERS_''${2^^}_PASSWORD" 2> /dev/null; }

    # [file] key type and body of a public key (from stdin without a file), without the comment
    pubkey() { cut -d' ' -f1-2 "$@"; }
  '';

  # Input: `secretspec export` of one host. $names: the secrets its config declares.
  # Output: exactly those secrets, with lowercase names; fails if one is missing or empty.
  selectSecrets = pkgs.writeText "select-secrets.jq" ''
    with_entries(.key |= ascii_downcase)
    | ($names - keys) as $missing
    | if $missing != [] then error("missing in bitwarden: \($missing)") end
    | with_entries(select(.key | IN($names[])))
    | [to_entries[] | select(.value == null or .value == "") | .key] as $empty
    | if $empty != [] then error("empty in bitwarden: \($empty)") end
  '';
in {
  packages = [
    inputs.deploy-rs.packages.${pkgs.stdenv.hostPlatform.system}.deploy-rs
    pkgs.ssh-to-age
    pkgs.sops
    pkgs.nixos-anywhere
    pkgs.disko
    pkgs.nixos-generators
    pkgs.bitwarden-cli
    pkgs.secretspec
    pkgs.jq
    pkgs.mkpasswd
    pkgs.expect

    pkgs.kubectl
    pkgs.fluxcd
    pkgs.age
    pkgs.yamlfmt
    pkgs.nfs-utils
    pkgs.k9s
    pkgs.k3s
    pkgs.pv-migrate
  ];

  scripts = {
    secrets-build = {
      exec = ''
        source ${common}

        if [ "$#" -lt 2 ]; then
          echo "usage: secrets-build outdir host..."
          exit 1
        fi

        # [json key] value of one secret
        secret() { printf '%s' "$1" | jq -r --arg k "$2" '.[$k]'; }

        # [host] the host's secrets from bitwarden as json, exactly the ones its config declares
        fetch_secrets() {
          local names
          names=$(nix eval --json ".#nixosConfigurations.$1.config.secrets" --apply builtins.attrNames)
          secretspec export --profile "$1" --format json | jq --argjson names "$names" -f ${selectSecrets}
        }

        # [host key] repo path of the public half of an ssh private key secret
        pub_file() {
          case $2 in
            host_ssh_ed25519_priv) echo "host/$1/ssh_host_ed25519_key.pub" ;;
            users_*_ssh_id_ed25519)
              local user=''${2#users_}
              echo "host/$1/user_''${user%_ssh_id_ed25519}_ssh_id_ed25519.pub"
              ;;
          esac
        }

        # [host json] ssh private keys must match their public halves in the repo,
        # a rerolled key must come with an updated .pub
        check_ssh_keys() {
          local key file
          for key in $(printf '%s' "$2" | jq -r 'keys[] | select(. == "host_ssh_ed25519_priv" or test("^users_.+_ssh_id_ed25519$"))'); do
            file=$(pub_file "$1" "$key")
            if [ "$(secret "$2" "$key" | ssh-keygen -y -f /dev/stdin | pubkey)" != "$(pubkey "$file" 2> /dev/null || true)" ]; then
              echo "$1: $key in bitwarden does not match $file" >&2
              exit 1
            fi
          done
        }

        # [host] the host key is also the host's sops identity, its age key must be
        # the one behind the &host anchor in .sops.yaml
        check_sops_identity() {
          local have want
          have=$(ssh-to-age < "host/$1/ssh_host_ed25519_key.pub")
          want=$(sed -n "s/.*&$1 \(age1[0-9a-z]*\).*/\1/p" .sops.yaml)
          if [ "$have" != "$want" ]; then
            echo "$1: host key is $have, but .sops.yaml has ''${want:-nothing}" >&2
            exit 1
          fi
        }

        # [json] passwords are stored in plain text, hashedPasswordFile needs a hash
        hash_passwords() {
          local json=$1 key hash
          for key in $(printf '%s' "$json" | jq -r 'keys[] | select(endswith("_password"))'); do
            hash=$(secret "$json" "$key" | mkpasswd -s)
            json=$(printf '%s' "$json" | HASH=$hash jq --arg k "$key" '.[$k] = env.HASH')
          done
          printf '%s' "$json"
        }

        # [host json] encrypts with the creation rule .sops.yaml has for the host
        encrypt() {
          printf '%s' "$2" | sops encrypt --input-type json --output-type yaml \
            --filename-override "host/$1/secrets.yaml" /dev/stdin
        }

        outdir=$1
        shift
        mkdir -p "$outdir"
        chmod 700 "$outdir"

        bw_unlock
        bw sync > /dev/null

        # plaintext only ever lives in memory and pipes, never touches the disk
        for h in "$@"; do
          json=$(fetch_secrets "$h")
          check_ssh_keys "$h" "$json"
          check_sops_identity "$h"
          json=$(hash_passwords "$json")
          encrypt "$h" "$json" > "$outdir/.$h.yaml.tmp"
          mv "$outdir/.$h.yaml.tmp" "$outdir/$h.yaml"
        done
      '';
      description = "[outdir host...] build encrypted sops files from bitwarden";
    };
    host-switch = {
      exec = ''
        source ${common}

        # unlock once, secrets-build and the sudo password below reuse the session
        bw_unlock

        host=$(hostname)
        build_secrets "$host"

        # the login password is in bitwarden too, use it to unlock sudo; if it
        # doesn't match (yet), sudo below just prompts as usual
        if password=$(user_password "$host" "$USER"); then
          printf '%s\n' "$password" | sudo -S -p "" -v 2> /dev/null || true
        fi
        unset password

        sudo nixos-rebuild "''${@:-switch}" --flake ".#$host" --override-input secrets "path:$secrets"
      '';
      description = "[nixos-rebuild action] rebuild this host (default: switch)";
    };
    host-deploy = {
      exec = ''
        source ${common}

        if [ "$#" -lt 1 ]; then
          echo "usage: host-deploy node..."
          exit 1
        fi

        # [node] refuse to deploy to a host whose ssh key differs from the repo (and so bitwarden)
        check_host_key() {
          local addr actual
          addr=$(nix eval --raw ".#deploy.nodes.$1.hostname")
          actual=$(ssh-keyscan -t ed25519 "$addr" 2> /dev/null | grep -v '^#' | cut -d' ' -f2-3 || true)
          if [ -z "$actual" ]; then
            echo "$1: could not read the host key of $addr" >&2
            exit 1
          fi
          if [ "$actual" != "$(pubkey "host/$1/ssh_host_ed25519_key.pub")" ]; then
            echo "$1: host key on $addr does not match host/$1/ssh_host_ed25519_key.pub" >&2
            exit 1
          fi
        }

        # [node] the ssh user's password is in bitwarden too, sudoExpect answers
        # deploy-rs's sudo prompts with it; nodes without one are asked on the terminal
        export_sudo_password() {
          local user password
          user=$(nix eval --raw ".#deploy.nodes.$1.profiles.system.sshUser")
          if password=$(user_password "$1" "$user"); then
            export "SUDO_PASSWORD_$1=$password"
          fi
        }

        # unlock once, secrets-build and the sudo passwords below reuse the session
        bw_unlock
        build_secrets "$@"

        targets=()
        for n in "$@"; do
          check_host_key "$n"
          export_sudo_password "$n"
          targets+=(".#$n")
        done

        # deploy-rs's flake check evaluates every host, but $secrets only holds the requested ones
        expect ${sudoExpect} deploy --skip-checks --targets "''${targets[@]}" -- --override-input secrets "path:$secrets"
      '';
      description = "[node...] deploy config to remote hosts";
    };
    install-remote = {
      exec = ''
        source ${common}

        if [ "$#" -lt 2 ]; then
          echo "usage: install-remote host user@ip"
          exit 1
        fi
        host=$1
        target=$2

        if [ ! -f "host/$host/ssh_host_ed25519_key" ]; then
          echo "missing host key host/$host/ssh_host_ed25519_key"
          exit 1
        fi

        # [attr] builds config.system.build.<attr> of the host with its secrets;
        # nixos-anywhere has no --override-input, so it gets the store paths instead
        build() {
          nix build --impure --no-link --print-out-paths \
            ".#nixosConfigurations.$host.config.system.build.$1" \
            --override-input secrets "path:$secrets"
        }

        build_secrets "$host"

        # files copied onto the new disk: the host key, which is also the host's sops identity
        extra=$(mktemp -d)
        on_exit "rm -rf '$extra'"
        install -d -m755 "$extra/persist/data/etc/ssh"
        install -m600 "host/$host/ssh_host_ed25519_key" "$extra/persist/data/etc/ssh/ssh_host_ed25519_key"

        # only for zfs encrypted filesystems
        # install -d -m755 "$extra/persist/data/etc/zfs"
        # install -m600 "host/$host/disk.key" "$extra/persist/data/etc/zfs/disk.key"

        # assigned first, set -e ignores a failing $(...) inside the arguments below
        disko=$(build diskoScript)
        toplevel=$(build toplevel)

        nixos-anywhere \
          --disk-encryption-keys /tmp/disk.key "host/$host/disk.key" \
          --extra-files "$extra" \
          --store-paths "$disko" "$toplevel" \
          "$target"
      '';
      description = "[host user@ip] install on remote host";
    };
    mkiso = {
      exec = "nixos-generate --format iso --configuration ./host/alp/default.nix -o result";
      description = "generate iso file";
    };
    writeiso = {
      exec = ''
        ISO=$(ls result/iso/*.iso)
        sudo dd if=$ISO of=$1 status=progress && sync
      '';
      description = "[/dev/XXX] write iso file to device";
    };
    mksecret = {
      exec = "sops --encrypt --encrypted-regex '^(data|stringData)$' --in-place $1";
      description = "[file] encrypt a kubernetes secret in place";
    };
  };

  enterShell = ''
    export KUBECONFIG=kubeconfig.yaml

    printf "\e[33m
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: script: "\\e[1m${name}\\e[0m\\e[33m \t\t -> ${script.description}") config.scripts)}
    \e[0m"
  '';
}
