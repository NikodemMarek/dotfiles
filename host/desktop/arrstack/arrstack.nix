{
  pkgs,
  lib,
  ...
}: {
  services = {
    radarr = {
      enable = true;
      openFirewall = true;
      settings.log.analyticsEnabled = false;
      settings.server.port = 7878;
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
      settings.server.port = 8989;
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
      settings.server.port = 8686;
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
      settings.server.port = 8787;
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
      settings.server.port = 9696;
      environmentFiles = [
        (pkgs.writeText "prowlarr.env" ''
          PROWLARR__AUTH__REQUIRED=DisabledForLocalAddresses
          PROWLARR__AUTH__APIKEY=c84cd4955ce246f7a8ad8be5a93c3667
        '')
      ];
    };
    jellyseerr = {
      enable = true;
      openFirewall = true;
      port = 5055;
    };
    qbittorrent = {
      enable = true;
      openFirewall = true;
      webuiPort = 6969;
      serverConfig = {
        LegalNotice.Accepted = true;
        Preferences = {
          "WebUI\\Username" = "admin";
          "WebUI\\Password_PBKDF2" = "@ByteArray(dcvfjm3frgrQVJcDcw2Pbg==:uylfPqs8/vOffnL832egaxT1AbJuVOzKMLwo1IAYLnwfokVNv7ALHSjKBithLLPC5WahX9TWEcF5jB0O+ca8Xw==)";
          "WebUI\\LocalHostAuth" = false;
        };
        BitTorrent."Session\\DefaultSavePath" = "/tmp/downloads";
      };
      user = "root";
    };
  };

  systemd.services = let
    sqlite = lib.getExe pkgs.sqlite;
  in {
    populate-prowlarr-db = {
      unitConfig = {
        After = ["prowlarr.service"];
        Requires = ["prowlarr.service"];
      };
      wantedBy = ["prowlarr.service"];
      serviceConfig = {
        Type = "simple";
        ExecStartPre = "/usr/bin/env sleep 5";
        ExecStart = "${sqlite} /var/lib/prowlarr/prowlarr.db \".read ${./prowlarr.sql}\"";
      };
    };
    populate-radarr-db = {
      unitConfig = {
        After = ["radarr.service"];
        Requires = ["radarr.service"];
      };
      wantedBy = ["radarr.service"];
      serviceConfig = {
        Type = "simple";
        ExecStartPre = "/usr/bin/env sleep 5";
        ExecStart = "${sqlite} /var/lib/radarr/.config/Radarr/radarr.db \".read ${./radarr.sql}\"";
      };
    };
    populate-sonarr-db = {
      unitConfig = {
        After = ["sonarr.service"];
        Requires = ["sonarr.service"];
      };
      wantedBy = ["sonarr.service"];
      serviceConfig = {
        Type = "simple";
        ExecStartPre = "/usr/bin/env sleep 5";
        ExecStart = "${sqlite} /var/lib/sonarr/.config/NzbDrone/sonarr.db \".read ${./sonarr.sql}\"";
      };
    };
    populate-lidarr-db = {
      unitConfig = {
        After = ["lidarr.service"];
        Requires = ["lidarr.service"];
      };
      wantedBy = ["lidarr.service"];
      serviceConfig = {
        Type = "simple";
        ExecStartPre = "/usr/bin/env sleep 5";
        ExecStart = "${sqlite} /var/lib/lidarr/.config/Lidarr/lidarr.db \".read ${./lidarr.sql}\"";
      };
    };
    populate-readarr-db = {
      unitConfig = {
        After = ["readarr.service"];
        Requires = ["readarr.service"];
      };
      wantedBy = ["readarr.service"];
      serviceConfig = {
        Type = "simple";
        ExecStartPre = "/usr/bin/env sleep 5";
        ExecStart = "${sqlite} /var/lib/readarr/readarr.db \".read ${./readarr.sql}\"";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/jellyseerr 0755 nobody nogroup -"
    "d /var/lib/jellyseerr/config 0755 nobody nogroup -"
    "L+ /var/lib/jellyseerr/config/settings.json - - - - ${./jellyseer.json}"
  ];
}
