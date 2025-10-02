# run with: sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./btrfs-persistence-swapfile.nix --arg device '"eg. sda"' --arg swap 'number'
{
  device,
  swap ? 4,
  ...
}: {
  disko.devices = {
    disk = {
      main = {
        device = "/dev/${device}";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";
              priority = 1;
            };

            esp = {
              size = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };

            root = {
              size = "100%";
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

                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
