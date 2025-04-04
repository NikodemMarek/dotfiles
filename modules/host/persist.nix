{
  lib,
  config,
  ...
}: {
  options.persist = let
    inherit (lib) mkEnableOption mkOption;
    inherit (lib.types) submodule listOf str;

    peristentCategory = {
      options = {
        directories = mkOption {
          type = listOf str;
          default = [];
        };
        files = mkOption {
          type = listOf str;
          default = [];
        };
      };
    };

    users = mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (
        submodule peristentCategory
      ));
      default = {};
    };
  in {
    enable = mkEnableOption "Enable impermanence";

    deviceService = mkOption {
      description = "Systemd device service to wait for, before pruning";
      type = str;
    };
    rootPath = mkOption {
      description = "Root device path";
      type = str;
    };

    # TODO: Allow arbitrary number of categories
    data = mkOption {
      type = submodule peristentCategory;
      default = {};
    };
    generated = mkOption {
      type = submodule peristentCategory;
      default = {};
    };

    inherit users;
  };

  config = let
    cfg = config.persist;

    inherit (lib) mkIf;
  in
    mkIf cfg.enable {
      boot.initrd = {
        supportedFilesystems = ["btrfs"];
        systemd = {
          enable = true;
          services.rollback = {
            description = "Rollback BTRFS root subvolume to a pristine state";
            wantedBy = [
              "initrd.target"
            ];
            before = [
              "sysroot.mount"
            ];
            requires = [cfg.deviceService];
            after = [cfg.deviceService];
            unitConfig.DefaultDependencies = "no";
            serviceConfig.Type = "oneshot";
            script = ''
              mkdir /btrfs_tmp
              mount ${cfg.rootPath} /btrfs_tmp
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
          };
        };
      };

      fileSystems."/persist".neededForBoot = true;
      programs.fuse.userAllowOther = true;

      environment.persistence = let
        usernames = lib.attrNames cfg.users;
        usersCategory = category:
          builtins.listToAttrs (
            map (user: {
              name = user;
              value = cfg.users.${user}.${category};
            })
            usernames
          );
      in {
        "/persist/data" = {
          hideMounts = true;
          directories =
            [
              {
                directory = "/etc/nixos";
                user = "root";
                group = "users";
                mode = "u=rwx,g=rwx,o=rx";
              }
            ]
            ++ cfg.data.directories;
          files = cfg.data.files;
          users = usersCategory "data";
        };
        "/persist/generated" = {
          hideMounts = true;
          directories =
            [
              "/var/log"
              "/var/lib/bluetooth"
              "/var/lib/nixos"
              "/var/lib/systemd"
              "/var/lib/sops-nix"
            ]
            ++ cfg.generated.directories;
          files =
            [
              "/etc/machine-id"
            ]
            ++ cfg.generated.files;
          users = usersCategory "generated";
        };
      };

      system.activationScripts.persistent-dirs.text = let
        mkHomePersist = user:
          lib.optionalString user.createHome ''
            mkdir -p /persist/data/${user.home}
            chown ${user.name}:${user.group} /persist/data/${user.home}
            chmod ${user.homeMode} /persist/data/${user.home}

            mkdir -p /persist/generated/${user.home}
            chown ${user.name}:${user.group} /persist/generated/${user.home}
            chmod ${user.homeMode} /persist/generated/${user.home}
          '';
        users = lib.attrValues config.users.users;
      in
        lib.concatLines (map mkHomePersist users);
    };
}
