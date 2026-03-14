{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix

    (import ../features/disko/btrfs-persistence-swapfile.nix {
      device = "nvme0n1";
      swap = 38;
    })

    ../features
    ../features/optional/systemd-boot.nix
    ../features/optional/tailscale.nix
    ../features/optional/libvirt.nix
    ../features/optional/maintenance.nix

    ./proxy.nix
  ];

  environment.systemPackages = [
    pkgs.ffmpeg
  ];

  networking = {
    hostId = "76cc60bb";
    hostName = "geralt";
    firewall.interfaces."tailscale0".allowedTCPPorts = [22 80 443];
    interfaces.eth0.wakeOnLan.enable = true;

    bridges."br0-virtint".interfaces = ["eth0"];
    nat.externalInterface = "br0-virtint";
    firewall.checkReversePath = "loose";
  };

  systemd.network = {
    links = {
      "10-wired-rename" = {
        matchConfig = {
          Type = "ether";
          Kind = "!*";
        };
        linkConfig = {Name = "eth0";};
      };
    };
    networks = {
      "10-wired-default" = {
        matchConfig.Name = "en*";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "yes";
        };
      };
    };
  };
  time.timeZone = "Europe/Warsaw";

  persist = {
    enable = true;
    deviceService = "dev-nvme0n1p2.device";
    rootPath = "/dev/nvme0n1p2";
  };
}
