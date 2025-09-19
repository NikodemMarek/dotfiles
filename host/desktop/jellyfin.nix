{
  containers.jellyfin = {
    autoStart = true;
    privateNetwork = false;
    forwardPorts = [
      {
        containerPort = 8096;
        hostPort = 8096;
        protocol = "tcp";
      }
    ];
    config = {
      pkgs,
      lib,
      ...
    }: {
      services.jellyfin = {
        enable = true;
      };
      environment.systemPackages = [
        pkgs.jellyfin
        pkgs.jellyfin-web
        pkgs.jellyfin-ffmpeg
      ];

      system.stateVersion = "25.11";

      networking = {
        firewall = {
          enable = true;
          allowedTCPPorts = [8096];
        };
        useHostResolvConf = lib.mkForce false;
      };

      services.resolved.enable = true;
    };
  };

  services = {
    traefik.dynamicConfigOptions.http = {
      services.jellyfin.loadBalancer.servers = [
        {
          url = "http://127.0.0.1:8096";
        }
      ];
      routers.jellyfin = {
        entryPoints = ["web"];
        rule = "Host(`jellyfin.local`)";
        service = "jellyfin";
        # tls.certResolver = "letsencrypt";
      };
    };
  };
}
