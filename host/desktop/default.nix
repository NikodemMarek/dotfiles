{config, ...}: let
  mediaDir = "/mnt/data";
in {
  imports = [
    ../features
    ../features/general/boot.nix
    ../features/general/networking.nix
    ../features/general/nix.nix
    ../features/general/openssh.nix
    ../features/general/security.nix
    ../features/general/sops.nix
    ../features/general/sudo.nix
    ../features/general/time.nix
    ../features/general/tools.nix
    ../features/general/zerotier.nix

    ./hardware-configuration.nix
    ./secrets.nix

    (import ../features/disko/btrfs-persistence-swapfile.nix {
      device = "nvme0n1";
      swap = 38;
    })
    (import ../features/disko/btrfs-single-partition.nix {
      device = "sda";
    })

    ../features/optional/libvirt.nix
    ./nfs.nix
    ./kubernetes
    ./server-tunnel.nix
    ./proxy.nix
    ./arrstack
    ./immich
    ./music
  ];

  networking = {
    hostId = "76cc60bb";
    hostName = "desktop";
    firewall.allowedTCPPorts = [22];
    interfaces.enp5s0.wakeOnLan.enable = true;

    bridges."br0".interfaces = ["enp5s0"];
    nat.externalInterface = "enp5s0";
  };
  systemd.network.networks = {
    "80-forward" = {
      matchConfig.Name = "enp5s0";
      networkConfig.IPMasquerade = "both";
    };
  };

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
          ../laptop/user_nikodem_ssh_id_ed25519.pub
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

  systemd.services.scheduled-poweroff = {
    enable = true;
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/usr/bin/env systemctl poweroff --when=+2h";
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
      '';
    };
  };
}
