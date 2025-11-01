{config, ...}: {
  networking.firewall.allowedUDPPorts = [4600];

  systemd.network = {
    enable = true;
    netdevs = {
      "60-wg2" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg2";
          MTUBytes = "1420";
        };
        wireguardConfig = {
          PrivateKeyFile = config.sops.secrets."wireguard/desktop_tunnel_private_key".path;
          ListenPort = 4600;
        };
        wireguardPeers = [
          {
            PublicKey = "NEt7Ye14buE3K+o7MbqMWkoO+t9CcEl2/xZyr2esKwo=";
            AllowedIPs = ["10.50.50.2/32"];
          }
        ];
      };
    };

    networks = {
      "60-wg2" = {
        matchConfig.Name = "wg2";
        address = ["10.50.50.1/24"];
      };
    };
  };

  services.traefik.dynamicConfigOptions.http = {
    services = {
      web-forward.loadBalancer.servers = [
        {
          url = "http://10.50.50.2:80";
        }
      ];
    };
    routers = {
      immich = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^immich\..+$`)";
        service = "web-forward";
        # tls.certResolver = "letsencrypt";
      };
      jellyfin = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^jellyfin\..+$`)";
        service = "web-forward";
        # tls.certResolver = "letsencrypt";
      };
      jellyseerr = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^jellyseerr\..+$`)";
        service = "web-forward";
        # tls.certResolver = "letsencrypt";
      };
      navidrome = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^navidrome\..+$`)";
        service = "web-forward";
        # tls.certResolver = "letsencrypt";
      };
    };
  };
}
