{
  config,
  pkgs,
  ...
}: let
  mediaDir = "/mnt/data";
in {
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix

    (import ../features/disko/btrfs-persistence-swapfile.nix {
      device = "nvme0n1";
      swap = 38;
    })
    (import ../features/disko/btrfs-single-partition.nix {
      device = "sda";
    })

    ../features
    ../features/optional/systemd-boot.nix
    ../features/optional/tailscale.nix
    ../features/optional/libvirt.nix

    ./nfs.nix
    ./kubernetes
    ./proxy.nix
    ./arrstack
    ./immich
    ./music
  ];

  environment.systemPackages = [
    pkgs.ffmpeg
  ];

  networking = {
    hostId = "76cc60bb";
    hostName = "geralt";
    firewall.interfaces."tailscale0".allowedTCPPorts = [22 80 443];
    interfaces.eth0.wakeOnLan.enable = true;

    bridges."br0-virtint".interfaces = ["eth0"];
    nat.externalInterface = "eth0";
  };

  systemd.network = {
    links = {
      "10-wired-rename" = {
        matchConfig = {
          Type = "ether";
          Kind = "!*";
        };
        linkConfig = {Name = "eth0";};
      };
    };
    networks = {
      "10-wired-default" = {
        matchConfig.Name = "en*";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "yes";
        };
      };
      "80-forward" = {
        matchConfig.Name = "eth0";
        networkConfig.IPMasquerade = "both";
      };
    };
  };
  time.timeZone = "Europe/Warsaw";

  persist = {
    enable = true;
    deviceService = "dev-nvme0n1p2.device";
    rootPath = "/dev/nvme0n1p2";
  };

  nix.settings.trusted-users = ["maintenance" "@wheel"];

  users = {
    users = {
      root.hashedPassword = "!";
      maintenance = {
        isNormalUser = true;
        hashedPasswordFile = config.sops.secrets."users/maintenance/password".path;
        extraGroups = ["wheel" "movies" "shows" "music" "books" "photos"];
        openssh.authorizedKeys.keyFiles = [
          ../yenn/user_nikodem_ssh_id_ed25519.pub
        ];
      };
    };
    groups = {
      movies.gid = 2010;
      shows.gid = 2020;
      music.gid = 2030;
      books.gid = 2040;
      photos.gid = 2050;
    };
  };

  system.activationScripts = {
    media-dirs = {
      text = ''
        mkdir -p ${mediaDir}/movies
        mkdir -p ${mediaDir}/shows
        mkdir -p ${mediaDir}/music
        mkdir -p ${mediaDir}/books
        mkdir -p ${mediaDir}/photos
        chown -R 0:${toString config.users.groups.movies.gid} ${mediaDir}/movies
        chown -R 0:${toString config.users.groups.shows.gid} ${mediaDir}/shows
        chown -R 0:${toString config.users.groups.music.gid} ${mediaDir}/music
        chown -R 0:${toString config.users.groups.books.gid} ${mediaDir}/books
        chown -R 0:${toString config.users.groups.photos.gid} ${mediaDir}/photos
        chmod 750 -R ${mediaDir}/movies
        chmod 750 -R ${mediaDir}/shows
        chmod 750 -R ${mediaDir}/music
        chmod 750 -R ${mediaDir}/books
        chmod 750 -R ${mediaDir}/photos

        mkdir -p /tmp/arrstack/downloads
        chmod 777 -R /tmp/arrstack/downloads
      '';
    };
  };
}
