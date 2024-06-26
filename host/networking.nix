{
  systemd.network.networks."default.network" = {
    matchConfig.Name = "en*";
    networkConfig = {
      Description = "default ethernet";
      DHCP = "yes";
    };
  };

  networking = {
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

    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
    };
  };
}
