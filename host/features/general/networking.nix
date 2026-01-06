{
  services.resolved.enable = true;
  systemd.network.enable = true;

  networking = {
    useNetworkd = true;
    nftables.enable = true;
    firewall.enable = true;
    enableIPv6 = true;
  };
}
