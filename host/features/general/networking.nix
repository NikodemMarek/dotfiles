{
  services.resolved.enable = true;

  systemd.network = {
    enable = true;
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

  networking = {
    useNetworkd = true;
    nftables.enable = true;
    firewall.enable = true;
    enableIPv6 = true;
  };
}
