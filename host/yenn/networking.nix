{
  imports = [
    ../features/optional/tailscale.nix
    ../features/optional/zerotier.nix
  ];

  networking = {
    nat.externalInterface = "wlan0";
    firewall.interfaces."tailscale0".allowedTCPPorts = [22];
  };

  systemd.network = {
    links = {
      "10-random-mac" = {
        matchConfig = {
          Type = "ether wlan wwan";
          Kind = "!*";
        };
        linkConfig = {MACAddressPolicy = "random";};
      };
    };
    networks = {
      "10-default-dhcp" = {
        matchConfig.Type = "ether wlan wwan";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "yes";
          IgnoreCarrierLoss = "3s";
        };
      };
      "80-forward" = {
        matchConfig.Name = "wlan0";
        networkConfig.IPMasquerade = "both";
      };
    };
    wait-online.enable = false;
  };
  boot.initrd.systemd.network.wait-online.enable = false;

  networking.wireless.iwd = {
    enable = true;
    settings = {
      General = {
        AddressRandomization = "network";
        AddressRandomizationRange = "full";
      };
      Network.EnableIPv6 = true;
      Settings.AutoConnect = true;
    };
  };

  persist.generated.directories = [
    {
      directory = "/var/lib/iwd";
      user = "root";
      group = "root";
    }
  ];
}
