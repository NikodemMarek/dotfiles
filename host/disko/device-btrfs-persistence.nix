# run with: sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./device-btrfs-persistence.nix --arg device '"eg. /dev/sda"' --arg swap 'number'
{
  device,
  swap ? 4,
  ...
}: {
  disko.devices = {
    disk.vdb = {
      inherit device;
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
                  swap.swapfile.size = "${builtins.toString swap}G";
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

  boot.resumeDevice = "/dev/root_vg/.swapvol/swapfile";
}
