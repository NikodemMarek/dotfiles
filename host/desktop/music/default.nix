{config, ...}: let
  navidromePort = 4533;

  musicDir = "/mnt/data/music";
in {
  containers.music = {
    autoStart = true;
    privateNetwork = false;
    forwardPorts = [
      {
        containerPort = 4533;
        hostPort = navidromePort;
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
    ./beets.nix
    ./yt-dlp.nix
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
      navidrome.loadBalancer.servers = [
        {
          url = "http://localhost:${toString navidromePort}";
        }
      ];
    };
    routers = {
      navidrome = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^navidrome\..+$`)";
        service = "navidrome";
        # tls.certResolver = "letsencrypt";
      };
    };
  };
}
