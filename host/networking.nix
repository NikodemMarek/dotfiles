{
  systemd.network.networks."default.network" = {
    networkConfig = {
      Description = "default ethernet";
      DHCP = "yes";
    };
  };

  networking = {
    useNetworkd = true;
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

    networkmanager.enable = true;
  };
}
