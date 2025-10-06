{config, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix
    (import ../features/disko/legacy-btrfs-persistence-swapfile.nix {
      device = "sda";
      swap = 4;
    })

    ../features
    ../features/general/nix.nix
    ../features/general/openssh.nix
    ../features/general/sops.nix

    ./proxy.nix
    ./cloudflared.nix
    ./immich.nix
    ./matrix-server.nix
    # ./monitoring.nix
  ];

  time.timeZone = "Etc/UTC";
  boot.loader.grub.enable = true;

  nix.settings.trusted-users = ["maintenance" "@wheel"];

  persist = {
    enable = true;
    deviceService = "dev-sda3.device";
    rootPath = "/dev/sda3";
  };

  users = {
    users = {
      root.hashedPassword = "!";
      maintenance = {
        isNormalUser = true;
        hashedPasswordFile = config.sops.secrets."users/maintenance/password".path;
        extraGroups = ["wheel"];
        openssh.authorizedKeys.keyFiles = [
          ../laptop/user_nikodem_ssh_id_ed25519.pub
        ];
      };
    };
    groups = {
      photos.gid = 2050;
    };
  };

  system.activationScripts = {
    media-dirs = {
      text = ''
        mkdir -p /mnt/data/photos
        chown -R 0:${toString config.users.groups.photos.gid} /mnt/data/photos
        chmod 770 -R /mnt/data/photos
      '';
    };
  };

  services.resolved.enable = true;
  systemd.network = {
    enable = true;
    networks = {
      "10-wan" = {
        matchConfig.Name = "en*";
        networkConfig.DHCP = "no";
        address = [
          "2a01:4f8:c17:b07::1/64"
        ];
        routes = [
          {Gateway = "fe80::1";}
        ];
      };
    };
  };

  networking = {
    hostName = "server";
    extraHosts = ''
      2a04:4e42:8d::729 tarballs.nixos.org
      2a04:4e42::729 cache.nixos.org
      2a00:1450:401b:80e::2011 proxy.golang.org
      2a00:1450:401b:810::2011 google.golang.org
      2a00:1450:401b:801::201b storage.googleapis.com
    '';
    enableIPv6 = true;
    useNetworkd = true;
    nftables.enable = true;
    firewall.enable = true;
  };

  programs = {
    neovim.enable = true;
    git.enable = true;
  };
}
