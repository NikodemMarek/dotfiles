{lib, ...}: {
  imports = [
    ./hardware-configuration.nix

    ../features
    ../features/optional/systemd-boot.nix
    ../features/optional/tailscale.nix
    ../features/optional/maintenance.nix

    ./k3s.nix
  ];

  boot.loader.systemd-boot.configurationLimit = lib.mkForce 1;
  networking = {
    hostName = "triss";
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
      "10-default-dhcp" = {
        matchConfig.Name = "eth0";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "yes";
        };
      };
    };
  };

  persist = {
    enable = true;
    deviceService = "dev-sda2.device";
    rootPath = "/dev/sda2";
    isCrypted = false;
  };

  networking.firewall.allowedTCPPorts = [
    22
  ];
  networking.firewall.allowedUDPPorts = [
    22
    53
  ];
}
