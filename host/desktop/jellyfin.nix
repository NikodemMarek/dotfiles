{config, ...}: let
  jellyseerrPort = 5055;
  jellyfinPort = 8096;

  mediaDir = "/persist/data/media";
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
      {
        containerPort = 5055;
        hostPort = jellyseerrPort;
        protocol = "tcp";
      }
    ];
    bindMounts = {
      "/mnt/data/movies" = {
        hostPath = "${mediaDir}/movies";
        isReadOnly = false;
      };
      "/mnt/data/shows" = {
        hostPath = "${mediaDir}/shows";
        isReadOnly = false;
      };
      "/mnt/data/music" = {
        hostPath = "${mediaDir}/music";
        isReadOnly = false;
      };
      "/mnt/data/books" = {
        hostPath = "${mediaDir}/books";
        isReadOnly = false;
      };
      "/var/lib" = {
        hostPath = "/var/lib/jellyfin";
        isReadOnly = false;
      };
    };
    config = {
      pkgs,
      lib,
      ...
    }: {
      services = {
        jellyfin = {
          enable = true;
          openFirewall = true;
          user = "root";
        };
        jellyseerr = {
          enable = true;
          openFirewall = true;
          port = 5055;
        };
      };
      environment.systemPackages = [
        pkgs.jellyfin
        pkgs.jellyfin-web
        pkgs.jellyfin-ffmpeg
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
      directory = "/var/lib/jellyfin";
      user = "root";
      group = "root";
      mode = "770";
    }
  ];

  services = {
    traefik.dynamicConfigOptions.http = {
      services = {
        jellyfin.loadBalancer.servers = [
          {
            url = "http://127.0.0.1:${toString jellyfinPort}";
          }
        ];
        jellyseerr.loadBalancer.servers = [
          {
            url = "http://127.0.0.1:${toString jellyseerrPort}";
          }
        ];
      };
      routers = {
        jellyfin = {
          entryPoints = ["web"];
          rule = "Host(`jellyfin.net`)";
          service = "jellyfin";
          # tls.certResolver = "letsencrypt";
        };
        jellyseerr = {
          entryPoints = ["web"];
          rule = "Host(`jellyseerr.net`)";
          service = "jellyseerr";
          # tls.certResolver = "letsencrypt";
        };
      };
    };
  };
}
