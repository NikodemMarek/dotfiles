# run with: sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./btrfs-single-partition.nix --arg device '"eg. /dev/sda"'
{
  device,
  options ? [],
  ...
}: {
  disko.devices = {
    disk.single = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              subvolumes = {
                "/data" = {
                  mountOptions = ["compress=zstd" "nofail" "rw" "users"] ++ options;
                  mountpoint = "/mnt/data";
                };
              };
            };
          };
        };
      };
    };
  };
}
