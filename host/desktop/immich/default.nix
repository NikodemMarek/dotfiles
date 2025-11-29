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
      "/var/lib/postgresql" = {
        hostPath = "/var/lib/immich/postgresql";
        isReadOnly = false;
      };
    };
    config = {lib, ...}: {
      imports = [
        ./immich.nix
      ];

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

  persist.generated.directories = [
    {
      directory = "/var/lib/immich/postgresql";
      user = "root";
      group = "root";
      mode = "770";
    }
  ];

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
