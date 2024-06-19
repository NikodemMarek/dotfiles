{
  imports = [
    (import ../../host/disko/device-btrfs-persistence.nix {
      device = "/dev/nvme0n1";
      swap = 15;
    })

    ../../host/impermanence.nix
    ../../host/sops.nix
    ../../host/hyprland.nix
    ../../host/docker.nix
    ../../host/dnscrypt-proxy2.nix
    ../../host/battery-saver.nix
    ../../host/bluetooth.nix
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
