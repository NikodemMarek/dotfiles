{config, ...}: {
  networking.useNetworkd = true;

  systemd.network = {
    enable = true;

    netdevs = {
      "5-wg0" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg0";
          MTUBytes = "1420";
        };
        wireguardConfig = {
          PrivateKeyFile = config.sops.secrets."wireguard/private_key".path;
        };
        wireguardPeers = [
          {
            PublicKey = "4XTKzCxivoyw70XtecEZXQpOYbATjl2nH9vcWCeK1zQ=";
            AllowedIPs = ["0.0.0.0/0" "::/0"];
            Endpoint = "[2a01:4f8:c17:b07::1]:4500";
          }
        ];
      };
    };
    networks."5-wg0" = {
      matchConfig.Name = "wg0";
      address = [
        "fd48:a8a8:ef08::2/64"
        "10.48.72.2/24"
      ];
      DHCP = "no";
      dns = ["2620:fe::9" "9.9.9.9"];
      gateway = [
        "fd48:a8a8:ef08::1"
        "10.48.72.1"
      ];
      networkConfig.IPv6AcceptRA = false;
    };
  };
}
