{hostname, ...}: {
  networking = {
    hostName = hostname;
    firewall.enable = true;
    nftables.enable = true;

    networkmanager = {
      enable = true;
      dns = "none";
    };

    nameservers = ["8.8.8.8" "8.8.4.4"];
  };
}
