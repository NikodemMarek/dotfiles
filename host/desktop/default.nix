{config, ...}: let
  mediaDir = "/mnt/data";
in {
  imports = [
    ../features
    ../features/general/networking.nix
    ../features/general/nix.nix
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

    ./proxy.nix
    ./dns.nix
    ./jellyfin
    ./arrstack
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
    };
  };

  networking = {
    hostId = "76cc60bb";
    hostName = "desktop";
    firewall.allowedTCPPorts = [22];
    # interfaces.enp5s0.wakeOnLan.enable = true;
  };

  persist = {
    enable = true;
    deviceService = "dev-nvme0n1p2.device";
    rootPath = "/dev/nvme0n1p2";
  };

  users = {
    users = {
      root = {
        password = "1234";
        openssh.authorizedKeys.keyFiles = [
          ../laptop/user_nikodem_ssh_id_ed25519.pub
          ../../home/nm1/user_nm1_ssh_id_ed25519.pub
        ];
      };
    };
    groups = {
      movies.gid = 2010;
      shows.gid = 2020;
      music.gid = 2030;
      books.gid = 2040;
    };
  };

  system.activationScripts = {
    media-dirs = {
      text = ''
        mkdir -p ${mediaDir}/movies
        mkdir -p ${mediaDir}/shows
        mkdir -p ${mediaDir}/music
        mkdir -p ${mediaDir}/books
        chown -R 0:${toString config.users.groups.movies.gid} ${mediaDir}/movies
        chown -R 0:${toString config.users.groups.shows.gid} ${mediaDir}/shows
        chown -R 0:${toString config.users.groups.music.gid} ${mediaDir}/music
        chown -R 0:${toString config.users.groups.books.gid} ${mediaDir}/books
        chmod 775 -R ${mediaDir}/movies
        chmod 775 -R ${mediaDir}/shows
        chmod 775 -R ${mediaDir}/music
        chmod 775 -R ${mediaDir}/books
      '';
    };
  };
}
