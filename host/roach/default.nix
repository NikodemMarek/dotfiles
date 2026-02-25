{config, ...}: {
  imports = [
    ./hardware-configuration.nix

    ../features
    ../features/optional/systemd-boot.nix
    ../features/optional/tailscale.nix

    ./printing.nix
    ./nfs.nix
  ];

  networking = {
    # hostId = "a3a35e1d";
    hostName = "roach";
    firewall.interfaces."tailscale0".allowedTCPPorts = [22];
  };

  time.timeZone = "Europe/Warsaw";

  persist = {
    enable = true;
    deviceService = "dev-nvme0n1p2.device";
    rootPath = "/dev/nvme0n1p2";
    isCrypted = false;
  };

  nix.settings.trusted-users = ["maintenance" "@wheel"];

  sops.secrets."users/maintenance/password" = {
    neededForUsers = true;
  };
  users.users = {
    root.hashedPassword = "!";
    maintenance = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/maintenance/password".path;
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keyFiles = [
        ../yenn/user_nikodem_ssh_id_ed25519.pub
      ];
    };
  };

  systemd.network = {
    links = {
      "10-wireless-rename" = {
        matchConfig = {
          Type = "wlan";
          Kind = "!*";
        };
        linkConfig = {Name = "wlan0";};
      };
    };
    networks = {
      "10-default-dhcp" = {
        matchConfig.Type = "ether wlan wwan";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "yes";
          IgnoreCarrierLoss = "3s";
        };
      };
    };
  };
  networking.wireless.iwd = {
    enable = true;
    settings = {
      Network.EnableIPv6 = true;
      Settings.AutoConnect = true;
    };
  };
  persist.generated.directories = [
    {
      directory = "/var/lib/iwd";
      user = "root";
      group = "root";
    }
  ];
}
