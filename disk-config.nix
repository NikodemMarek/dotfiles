{settings, ...}: {
  disko.devices = {
    disk.vdb = {
      device = settings.drive;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          esp = {
            priority = 1;
            name = "boot";
            size = "500M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            name = "root";
            size = "100%";
            content = {
              type = "lvm_pv";
              vg = "root_vg";
            };
          };
        };
      };
    };

    lvm_vg = {
      root_vg = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "100%FREE";
            content = {
              type = "btrfs";
              extraArgs = ["-f"];

              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                };

                "/swap" = {
                  mountpoint = "/.swapvol";
                  swap.swapfile.size = "15G";
                };

                "/nix" = {
                  mountOptions = ["subvol=nix" "compress=zstd" "noatime"];
                  mountpoint = "/nix";
                };

                "/persist" = {
                  mountOptions = ["subvol=persist" "compress=zstd"];
                  mountpoint = "/persist";
                };
              };
            };
          };
        };
      };
    };
  };
}
