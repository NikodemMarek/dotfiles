{
  inputs,
  lib,
  users,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir /btrfs_tmp
    mount /dev/root_vg/root /btrfs_tmp
    if [[ -e /btrfs_tmp/root ]]; then
        mkdir -p /btrfs_tmp/old_roots
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
        mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
    fi

    delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/btrfs_tmp/$i"
        done
        btrfs subvolume delete "$1"
    }

    for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
        delete_subvolume_recursively "$i"
    done

    btrfs subvolume create /btrfs_tmp/root
    umount /btrfs_tmp
  '';

  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/sops-nix"
      "/etc/NetworkManager/system-connections"
      {
        directory = "/dotfiles";
        user = "root";
        group = "users";
        mode = "u=rwx,g=rwx,o=rx";
      }
      # music
      {
        directory = "/home/music";
        user = "music";
        group = "music";
        mode = "u=rwx,g=rwx,o=rx";
      }
      {
        directory = "/home/music/data";
        user = "music";
        group = "music";
        mode = "u=rwx,g=rwx,o=rx";
      }
      {
        directory = "/home/music/to-add";
        user = "music";
        group = "music";
        mode = "u=rwx,g=rwx,o=rx";
      }
    ];
    files = [
      "/etc/machine-id"
      # music
      {
        file = "/home/music/musiclib.db";
        parentDirectory = {mode = "u=rwx,g=rwx,o=rx";};
      }
      {
        file = "/home/music/.envrc";
        parentDirectory = {mode = "u=rx,g=rx,o=rx";};
      }
    ];
    users = builtins.listToAttrs (builtins.map
      (user: {
        name = user.username;
        value = {
          directories = [
            ".config"

            "projects"
            "documents"
            "screenshots"

            ".ssh"
            ".local/share/keyrings"
            ".local/share/direnv"

            ".cache"
            ".mozilla"
            ".npm"
            ".cargo"
            ".java"
            ".hyprland"
            ".gradle"
            ".docker"
            ".dockercache"
          ];
        };
      })
      users);
  };
}
