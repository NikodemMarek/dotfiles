{config, ...}: let
  radarrPort = 7878;
  sonarrPort = 8989;
  lidarrPort = 8686;
  readarrPort = 8787;
  prowlarrPort = 9696;
  torrentPort = 6969;

  mediaDir = "/mnt/data";
in {
  containers.arrstack = {
    autoStart = true;
    privateNetwork = false;
    forwardPorts = [
      {
        containerPort = 7878;
        hostPort = radarrPort;
        protocol = "tcp";
      }
      {
        containerPort = 8989;
        hostPort = sonarrPort;
        protocol = "tcp";
      }
      {
        containerPort = 8686;
        hostPort = lidarrPort;
        protocol = "tcp";
      }
      {
        containerPort = 8787;
        hostPort = readarrPort;
        protocol = "tcp";
      }
      {
        containerPort = 9696;
        hostPort = prowlarrPort;
        protocol = "tcp";
      }
      {
        containerPort = 5055;
        hostPort = 5055;
        protocol = "tcp";
      }
      {
        containerPort = 6969;
        hostPort = torrentPort;
        protocol = "tcp";
      }
    ];
    bindMounts = {
      "/mnt/movies" = {
        hostPath = "${mediaDir}/movies";
        isReadOnly = false;
      };
      "/mnt/shows" = {
        hostPath = "${mediaDir}/shows";
        isReadOnly = false;
      };
      "/mnt/music" = {
        hostPath = "${mediaDir}/music";
        isReadOnly = false;
      };
      "/mnt/books" = {
        hostPath = "${mediaDir}/books";
        isReadOnly = false;
      };
    };
    config = {lib, ...}: {
      imports = [
        ./arrstack.nix
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

  services = {
    traefik.dynamicConfigOptions.http = {
      services = {
        radarr.loadBalancer.servers = [
          {
            url = "http://127.0.0.1:${toString radarrPort}";
          }
        ];
        sonarr.loadBalancer.servers = [
          {
            url = "http://127.0.0.1:${toString sonarrPort}";
          }
        ];
        lidarr.loadBalancer.servers = [
          {
            url = "http://127.0.0.1:${toString lidarrPort}";
          }
        ];
        readarr.loadBalancer.servers = [
          {
            url = "http://127.0.0.1:${toString readarrPort}";
          }
        ];
        prowlarr.loadBalancer.servers = [
          {
            url = "http://127.0.0.1:${toString prowlarrPort}";
          }
        ];
        torrent.loadBalancer.servers = [
          {
            url = "http://127.0.0.1:${toString torrentPort}";
          }
        ];
      };
      routers = {
        radarr = {
          entryPoints = ["web"];
          rule = "Host(`radarr.net`)";
          service = "radarr";
          # tls.certResolver = "letsencrypt";
        };
        sonarr = {
          entryPoints = ["web"];
          rule = "Host(`sonarr.net`)";
          service = "sonarr";
          # tls.certResolver = "letsencrypt";
        };
        lidarr = {
          entryPoints = ["web"];
          rule = "Host(`lidarr.net`)";
          service = "lidarr";
          # tls.certResolver = "letsencrypt";
        };
        readarr = {
          entryPoints = ["web"];
          rule = "Host(`readarr.net`)";
          service = "readarr";
          # tls.certResolver = "letsencrypt";
        };
        prowlarr = {
          entryPoints = ["web"];
          rule = "Host(`prowlarr.net`)";
          service = "prowlarr";
          # tls.certResolver = "letsencrypt"
        };
        torrent = {
          entryPoints = ["web"];
          rule = "Host(`torrent.net`)";
          service = "torrent";
          # tls.certResolver = "letsencrypt"
        };
      };
    };
  };
}
