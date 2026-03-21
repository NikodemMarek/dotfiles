{
  services.resolved.enable = true;
  systemd.network.enable = true;

  networking = {
    useNetworkd = true;
    useDHCP = false;
    enableIPv6 = true;

    firewall.enable = true;
    nftables.enable = true;
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "net.ipv4.conf.all.rp_filter" = 2;
  };
}
