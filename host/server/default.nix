{config, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix
    (import ../features/disko/legacy-btrfs-persistence-swapfile.nix {
      device = "sda";
      swap = 4;
    })

    ../features
    ../features/optional/tailscale.nix

    ./proxy.nix
    ./desktop-forward.nix
    ./cloudflared
    ./vpn.nix

    # ./matrix-server
  ];

  time.timeZone = "Etc/UTC";
  boot.loader.grub.enable = true;

  nix.settings.trusted-users = ["maintenance" "@wheel"];

  persist = {
    enable = true;
    deviceService = "dev-sda3.device";
    rootPath = "/dev/sda3";
  };

  users.users = {
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

  networking = {
    hostName = "server";
    firewall.interfaces."tailscale0".allowedTCPPorts = [22];
  };
  systemd.network.networks = {
    "10-wan" = {
      matchConfig.Name = "en*";
      networkConfig = {
        DHCP = "ipv4";
        IPMasquerade = "both";
      };
      address = [
        "2a01:4f8:c17:b07::1/64"
      ];
      routes = [
        {Gateway = "fe80::1";}
      ];
    };
  };
}
