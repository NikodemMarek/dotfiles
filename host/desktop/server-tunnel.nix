{config, ...}: {
  networking = {
    useNetworkd = true;
    firewall.interfaces."wg0".allowedTCPPorts = [80 443];
  };

  systemd.network = {
    enable = true;

    netdevs = {
      "10-wg0" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg0";
          MTUBytes = "1420";
        };
        wireguardConfig = {
          PrivateKeyFile = config.sops.secrets."wireguard/server_tunnel_private_key".path;
        };
        wireguardPeers = [
          {
            PublicKey = "AYNrIIt59P1roEwzq40IptQoKffBB4Q8tOUfc/wfv2k=";
            AllowedIPs = ["0.0.0.0/0"];
            Endpoint = "vpn.nkmrk.com:4600";
          }
        ];
      };
    };
    networks."10-wg0" = {
      matchConfig.Name = "wg0";
      address = ["10.50.50.2/24"];
      DHCP = "no";
      networkConfig.IPv6AcceptRA = false;
    };
  };
}
