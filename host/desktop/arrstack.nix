{
  containers.arrstack = {
    autoStart = true;
    privateNetwork = false;
    forwardPorts = [
      {
        containerPort = 7878;
        hostPort = 7878;
        protocol = "tcp";
      }
      {
        containerPort = 8686;
        hostPort = 8686;
        protocol = "tcp";
      }
      {
        containerPort = 9696;
        hostPort = 9696;
        protocol = "tcp";
      }
    ];
    bindMounts = {
      "/mnt/data" = {
        hostPath = "/tmp/arrstack";
        isReadOnly = false;
      };
    };
    config = {lib, ...}: {
      services = {
        radarr = {
          enable = true;
          openFirewall = true;
          settings.log.analyticsEnabled = false;
          dataDir = "/mnt/movies";
        };
        lidarr = {
          enable = true;
          openFirewall = true;
          settings.log.analyticsEnabled = false;
          dataDir = "/mnt/music";
        };
        prowlarr = {
          enable = true;
          openFirewall = true;
          settings.log.analyticsEnabled = false;
          dataDir = "/mnt/prowlarr";
        };
      };

      system.stateVersion = "25.11";

      networking = {
        firewall.enable = true;
        useHostResolvConf = lib.mkForce false;
      };

      services.resolved.enable = true;
    };
  };

  services = {
    traefik.dynamicConfigOptions.http = {
      services = {
        radarr.loadBalancer.servers = [
          {
            url = "http://127.0.0.1:7878";
          }
        ];
        lidarr.loadBalancer.servers = [
          {
            url = "http://127.0.0.1:8686";
          }
        ];
        prowlarr.loadBalancer.servers = [
          {
            url = "http://127.0.0.1:9696";
          }
        ];
      };
      routers = {
        radarr = {
          entryPoints = ["web"];
          rule = "Host(`radarr.local`)";
          service = "radarr";
          # tls.certResolver = "letsencrypt";
        };
        lidarr = {
          entryPoints = ["web"];
          rule = "Host(`lidarr.local`)";
          service = "lidarr";
          # tls.certResolver = "letsencrypt";
        };
        prowlarr = {
          entryPoints = ["web"];
          rule = "Host(`prowlarr.local`)";
          service = "prowlarr";
          # tls.certResolver = "letsencrypt"
        };
      };
    };
  };
}
