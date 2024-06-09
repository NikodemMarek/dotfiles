{
  imports = [
    (import ../modules/disko/device-btrfs-persistence.nix {
      device = "/dev/nvme0n1";
      swap = 38;
    })

    ../modules/disko
    ../modules/impermanence.nix
    ../modules/sops.nix
    ../modules/hyprland.nix
    ../modules/docker.nix
    ../modules/dnscrypt-proxy2.nix
    ../modules/music.nix
    ../modules/battery-saver.nix
    ../modules/bluetooth.nix
  ];

  networking.hostName = "LP-043";
}
# {
#   name = "eDP-1";
#   width = 1920;
#   height = 1080;
#   refreshRate = 60;
#   offsetX = 0;
#   offsetY = 0;
#   transform = 0;
# }
# {
#   name = "DP-3";
#   width = 1920;
#   height = 1080;
#   refreshRate = 60;
#   offsetX = 0;
#   offsetY = 0;
#   transform = 0;
# }
# {
#   name = "DP-4";
#   width = 1920;
#   height = 1080;
#   refreshRate = 60;
#   offsetX = 0;
#   offsetY = 0;
#   transform = 0;
# }
