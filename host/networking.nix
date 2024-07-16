{config, ...}: {
  systemd.network = {
    enable = true;
    networks = {
      "10-wired-default" = {
        matchConfig.Name = "en*";
        networkConfig = {
          DHCP = "ipv4";
        };
      };
      "20-wireless-default" = {
        matchConfig.Name = "wl*";
        networkConfig = {
          DHCP = "ipv4";
          IgnoreCarrierLoss = "3s";
        };
      };
    };
  };

  sops.secrets.networks = {};

  networking = {
    useNetworkd = true;
    wireless = {
      enable = true;
      userControlled.enable = true;
      environmentFile = config.sops.secrets.networks.path;
      networks = {
        "Meshki56".psk = "@PSK_Meshki56@";
        "hot_pot" = {
          psk = "@PSK_hot_pot@";
          priority = -10;
        };
      };
    };

    nftables.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [22];
      allowedTCPPortRanges = [
        {
          from = 5000;
          to = 5999;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 5000;
          to = 5999;
        }
      ];
    };
  };
}
