{config, ...}: let
  immichPort = 2283;

  photosDir = "/mnt/data/photos";
in {
  containers.immich = {
    autoStart = true;
    privateNetwork = false;
    forwardPorts = [
      {
        containerPort = 2283;
        hostPort = immichPort;
        protocol = "tcp";
      }
    ];
    bindMounts = {
      "/mnt/photos" = {
        hostPath = photosDir;
        isReadOnly = false;
      };
    };
    config = {lib, ...}: {
      services.immich = {
        enable = true;
        port = 2283;
        openFirewall = true;
        mediaLocation = "/mnt/photos";
        group = "photos";
        settings = {
          reverseGeocoding.enabled = true;
          newVersionCheck.enabled = false;
          server = {
            externalDomain = "";
          };
          storageTemplate = {
            enabled = true;
            hashVerificationEnabled = true;
            template = "{{y}}/{{MMM}}/{{dd}}/{{filename}}";
          };
        };
        environment = {
          IMMICH_TELEMETRY_INCLUDE = "all";
        };
      };

      users.groups = {
        photos.gid = config.users.groups.photos.gid;
      };

      system.stateVersion = "25.11";

      networking = {
        firewall.enable = true;
        useHostResolvConf = lib.mkForce false;
      };

      services.resolved.enable = true;
    };
  };

  services.traefik.dynamicConfigOptions.http = {
    services = {
      immich.loadBalancer.servers = [
        {
          url = "http://localhost:${toString immichPort}";
        }
      ];
    };
    routers = {
      immich = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^immich\..+$`)";
        service = "immich";
        # tls.certResolver = "letsencrypt";
      };
    };
  };
}
