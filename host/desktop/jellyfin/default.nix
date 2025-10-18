{
  config,
  inputs,
  ...
}: let
  jellyfinPort = 8096;

  mediaDir = "/mnt/data";
in {
  containers.jellyfin = {
    autoStart = true;
    privateNetwork = false;
    forwardPorts = [
      {
        containerPort = 8096;
        hostPort = jellyfinPort;
        protocol = "tcp";
      }
    ];
    bindMounts = {
      "/mnt/movies" = {
        hostPath = "${mediaDir}/movies";
        isReadOnly = true;
      };
      "/mnt/shows" = {
        hostPath = "${mediaDir}/shows";
        isReadOnly = true;
      };
      "/mnt/music" = {
        hostPath = "${mediaDir}/music";
        isReadOnly = true;
      };
      "/mnt/books" = {
        hostPath = "${mediaDir}/books";
        isReadOnly = true;
      };
      "/var/lib/jellyfin/data" = {
        hostPath = "/var/lib/jellyfin/data";
        isReadOnly = false;
      };
      "/var/lib/jellyfin/metadata" = {
        hostPath = "/var/lib/jellyfin/metadata";
        isReadOnly = false;
      };
      "/var/lib/jellyfin/playlists" = {
        hostPath = "/var/lib/jellyfin/playlists";
        isReadOnly = false;
      };
    };
    config = {lib, ...}: {
      imports = [
        inputs.declarative-jellyfin.nixosModules.default
        ./jellyfin.nix
      ];

      users.groups = {
        movies.gid = config.users.groups.movies.gid;
        shows.gid = config.users.groups.shows.gid;
        music.gid = config.users.groups.music.gid;
        books.gid = config.users.groups.books.gid;
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
      directory = "/var/lib/jellyfin/data";
      user = "root";
      group = "root";
      mode = "770";
    }
    {
      directory = "/var/lib/jellyfin/metadata";
      user = "root";
      group = "root";
      mode = "770";
    }
    {
      directory = "/var/lib/jellyfin/playlists";
      user = "root";
      group = "root";
      mode = "770";
    }
  ];

  services.traefik.dynamicConfigOptions.http = {
    services = {
      jellyfin.loadBalancer.servers = [
        {
          url = "http://localhost:${toString jellyfinPort}";
        }
      ];
    };
    routers = {
      jellyfin = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^jellyfin\..+$`)";
        service = "jellyfin";
        # tls.certResolver = "letsencrypt";
      };
    };
  };
}
