{
  imports = [
    (import ../modules/disko/device-btrfs-persistence.nix {
      device = "/dev/nvme0n1";
      swap = 15;
    })

    ../modules/impermanence.nix
    ../modules/sops.nix
    ../modules/hyprland.nix
    ../modules/docker.nix
    ../modules/dnscrypt-proxy2.nix
    ../modules/music.nix
    ../modules/battery-saver.nix
    ../modules/bluetooth.nix
  ];

  networking.hostName = "laptop";

  services = {
    music = {
      enable = true;
      anysync = true;
      persistent = true;
    };
  };
}
