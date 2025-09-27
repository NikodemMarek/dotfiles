{config, ...}: let
  radarrPort = 7878;
  sonarrPort = 8989;
  lidarrPort = 8686;
  readarrPort = 8787;
  prowlarrPort = 9696;
  torrentPort = 6969;

  mediaDir = "/persist/data/media";
in {
  containers.arrstack = {
    autoStart = true;
    privateNetwork = false;
    forwardPorts = [
      {
        containerPort = radarrPort;
        hostPort = radarrPort;
        protocol = "tcp";
      }
      {
        containerPort = sonarrPort;
        hostPort = sonarrPort;
        protocol = "tcp";
      }
      {
        containerPort = lidarrPort;
        hostPort = lidarrPort;
        protocol = "tcp";
      }
      {
        containerPort = readarrPort;
        hostPort = readarrPort;
        protocol = "tcp";
      }
      {
        containerPort = prowlarrPort;
        hostPort = prowlarrPort;
        protocol = "tcp";
      }
      {
        containerPort = torrentPort;
        hostPort = torrentPort;
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
      # "/var/lib" = {
      #   hostPath = "/var/lib/arrstack";
      #   isReadOnly = false;
      # };
    };
    config = {
      pkgs,
      lib,
      ...
    }: {
      services = {
        radarr = {
          enable = true;
          openFirewall = true;
          settings.log.analyticsEnabled = false;
          settings.server.port = radarrPort;
          environmentFiles = [
            (pkgs.writeText "radarr.env" ''
              RADARR__AUTH__REQUIRED=DisabledForLocalAddresses
              RADARR__AUTH__APIKEY=d0f9aef01b76408dbcfdac38725c1e09
            '')
          ];
          user = "root";
          group = "movies";
        };
        sonarr = {
          enable = true;
          openFirewall = true;
          settings.log.analyticsEnabled = false;
          settings.server.port = sonarrPort;
          environmentFiles = [
            (pkgs.writeText "sonarr.env" ''
              SONARR__AUTH__REQUIRED=DisabledForLocalAddresses
              SONARR__AUTH__APIKEY=5e3a424b16f04d76b6f4c7d64b3b371c
            '')
          ];
          user = "root";
          group = "shows";
        };
        lidarr = {
          enable = true;
          openFirewall = true;
          settings.log.analyticsEnabled = false;
          settings.server.port = lidarrPort;
          environmentFiles = [
            (pkgs.writeText "sonarr.env" ''
              LIDARR__AUTH__REQUIRED=DisabledForLocalAddresses
              LIDARR__AUTH__APIKEY=44ebf8f7f5834d4c819e8113fc6c9b9f
            '')
          ];
          user = "root";
          group = "music";
        };
        readarr = {
          enable = true;
          openFirewall = true;
          settings.log.analyticsEnabled = false;
          settings.server.port = readarrPort;
          environmentFiles = [
            (pkgs.writeText "sonarr.env" ''
              READARR__AUTH__REQUIRED=DisabledForLocalAddresses
              READARR__AUTH__APIKEY=615e8851fbbc422ba64d368cb2eeb987
            '')
          ];
          user = "root";
          group = "books";
        };
        prowlarr = {
          enable = true;
          openFirewall = true;
          settings.log.analyticsEnabled = false;
          settings.server.port = prowlarrPort;
          environmentFiles = [
            (pkgs.writeText "prowlarr.env" ''
              PROWLARR__AUTH__REQUIRED=DisabledForLocalAddresses
              PROWLARR__AUTH__APIKEY=c84cd4955ce246f7a8ad8be5a93c3667
            '')
          ];
        };
        qbittorrent = {
          enable = true;
          openFirewall = true;
          webuiPort = torrentPort;
          serverConfig = {
            LegalNotice.Accepted = true;
            Preferences = {
              "WebUI\\Username" = "admin";
              "WebUI\\Password_PBKDF2" = "@ByteArray(dcvfjm3frgrQVJcDcw2Pbg==:uylfPqs8/vOffnL832egaxT1AbJuVOzKMLwo1IAYLnwfokVNv7ALHSjKBithLLPC5WahX9TWEcF5jB0O+ca8Xw==)";
              "WebUI\\LocalHostAuth" = false;
            };
        BitTorrent."Session\\DefaultSavePath"="/tmp";
          };
          user = "root";
        };
      };

      users.groups = {
        movies.gid = config.users.groups.movies.gid;
        shows.gid = config.users.groups.shows.gid;
        music.gid = config.users.groups.music.gid;
        books.gid = config.users.groups.books.gid;
      };

      systemd.services.populate-dbs = {
        after = [ "prowlarr.target" "radarr.target" "sonarr.target" "lidarr.target" "readarr.target" ];
        serviceConfig = let
            sqlite = lib.getExe pkgs.sqlite;
        in {
            Type = "oneshot";
            ExecStart = ''${lib.getExe (pkgs.writeShellScript "populate-dbs" ''
                ${sqlite} /var/lib/prowlarr/prowlarr.db ".read ${./arrstack-config/prowlarr.sql}"
                ${sqlite} /var/lib/radarr/.config/Radarr/radarr.db ".read ${./arrstack-config/radarr.sql}"
                ${sqlite} /var/lib/sonarr/.config/NzbDrone/sonarr.db ".read ${./arrstack-config/sonarr.sql}"
                ${sqlite} /var/lib/lidarr/.config/Lidarr/lidarr.db ".read ${./arrstack-config/lidarr.sql}"
                ${sqlite} /var/lib/readarr/readarr.db ".read ${./arrstack-config/readarr.sql}"
            '')}'';
        };
      };

      # system.activationScripts = {
      #   populate-dbs = {
      #     text = ''
      #       mkdir -p /var/lib/prowlarr
      #       # cp ${./arrstack-config/prowlarr.db} /var/lib/prowlarr/prowlarr.db
      #       # cp ${./arrstack-config/prowlarr-config.xml} /var/lib/prowlarr/config.xml
      #       chown 0:0 -R /var/lib/prowlarr
      #       chmod 770 -R /var/lib/prowlarr
      #
      #       mkdir -p /var/lib/radarr/.config/Radarr
      #       # cp ${./arrstack-config/radarr.db} /var/lib/radarr/.config/Radarr/radarr.db
      #       # cp ${./arrstack-config/radarr-config.xml} /var/lib/radarr/.config/Radarr/config.xml
      #       chown 0:0 -R /var/lib/radarr
      #       chmod 770 -R /var/lib/radarr
      #
      #       mkdir -p /var/lib/sonarr/.config/NzbDrone
      #       # cp ${./arrstack-config/sonarr.db} /var/lib/sonarr/.config/NzbDrone/sonarr.db
      #       # cp ${./arrstack-config/sonarr-config.xml} /var/lib/sonarr/.config/NzbDrone/config.xml
      #       chown 0:0 -R /var/lib/sonarr
      #       chmod 770 -R /var/lib/sonarr
      #
      #       mkdir -p /var/lib/lidarr/.config/Lidarr
      #       # cp ${./arrstack-config/lidarr.db} /var/lib/lidarr/.config/Lidarr/lidarr.db
      #       # cp ${./arrstack-config/lidarr-config.xml} /var/lib/lidarr/.config/Lidarr/config.xml
      #       chown 0:0 -R /var/lib/lidarr
      #       chmod 770 -R /var/lib/lidarr
      #
      #       mkdir -p /var/lib/readarr
      #       # cp ${./arrstack-config/readarr.db} /var/lib/readarr/readarr.db
      #       # cp ${./arrstack-config/readarr-config.xml} /var/lib/readarr/config.xml
      #       chown 0:0 -R /var/lib/readarr
      #       chmod 770 -R /var/lib/readarr
      #     '';
      #   };
      # };

      system.stateVersion = "25.11";

      networking = {
        firewall.enable = true;
        useHostResolvConf = lib.mkForce false;
      };

      services.resolved.enable = true;
    };
  };

  # persist.generated.directories = [
  #   {
  #     directory = "/var/lib/arrstack";
  #     user = "root";
  #     group = "root";
  #     mode = "770";
  #   }
  # ];

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
