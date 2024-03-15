{hostname, ...}: {
  networking = {
    hostName = hostname;
    firewall.enable = true;
    nftables.enable = true;

    networkmanager.enable = true;
  };
}
