let
  radarrPort = 7878;
  sonarrPort = 8989;
  lidarrPort = 8686;
  readarrPort = 8787;
  prowlarrPort = 9696;
  torrentPort = 6969;

  mediaDir = "/mnt/data";
in {
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [7878 8989 8686 8787 9696 6969];

  system.activationScripts = {
    arrstack-download-dirs = {
      text = ''
        mkdir -p /tmp/arrstack/downloads
        chmod 777 -R /tmp/arrstack/downloads
      '';
    };
  };

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
      "/tmp/downloads" = {
        hostPath = "/tmp/arrstack/downloads";
        isReadOnly = false;
      };
    };
    config = {lib, ...}: {
      imports = [
        ./arrstack.nix
      ];

      system.stateVersion = "25.11";

      networking = {
        firewall.enable = true;
        useHostResolvConf = lib.mkForce false;
      };

      services.resolved.enable = true;
    };
  };
}
