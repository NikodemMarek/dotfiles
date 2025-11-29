{config, ...}: let
  subsonicPort = 4533;

  musicDir = "/mnt/data/music";
in {
  containers.music = {
    autoStart = true;
    privateNetwork = false;
    forwardPorts = [
      {
        containerPort = 4533;
        hostPort = subsonicPort;
        protocol = "tcp";
      }
    ];
    bindMounts = {
      "/mnt/music" = {
        hostPath = musicDir;
        isReadOnly = true;
      };
      "/var/lib/navidrome" = {
        hostPath = "/var/lib/music/navidrome";
        isReadOnly = false;
      };
    };
    config = {lib, ...}: {
      imports = [
        ./navidrome.nix
      ];

      users.groups = {
        music.gid = config.users.groups.music.gid;
      };

      system.stateVersion = "25.11";

      networking = {
        firewall.enable = true;
        useHostResolvConf = lib.mkForce false;
      };

      services.resolved.enable = true;
    };
  };

  imports = [
    ./management.nix
  ];

  persist.generated.directories = [
    {
      directory = "/var/lib/music/navidrome";
      user = "root";
      group = "root";
      mode = "770";
    }
  ];

  services.traefik.dynamicConfigOptions.http = {
    services = {
      subsonic.loadBalancer.servers = [
        {
          url = "http://localhost:${toString subsonicPort}";
        }
      ];
    };
    routers = {
      subsonic = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^subsonic\..+$`)";
        service = "subsonic";
        # tls.certResolver = "letsencrypt";
      };
    };
  };
}
