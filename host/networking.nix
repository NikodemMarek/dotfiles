{
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
      dns = "none";
    };

    nameservers = ["8.8.8.8" "8.8.4.4"];
  };
}
