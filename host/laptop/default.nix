{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix

    (import ../features/disko/btrfs-persistence-swapfile.nix {
      device = "/dev/nvme0n1";
      swap = 15;
    })

    ../features
    ../features/general

    ../features/optional/battery-saver.nix
    ../features/optional/bluetooth.nix
    ../features/optional/libvirt.nix
    ../features/optional/tailscale.nix
    ../features/optional/zerotier.nix
    ../features/optional/syncthing.nix

    ../../home/nikodem/persist.nix
  ];

  sops.secrets."wireguard/private_key" = {
    owner = "systemd-network";
  };

  networking = {
    hostName = "laptop";
    bridges."br0".interfaces = ["wlp0s20f3"];
    nat.externalInterface = "wlp0s20f3";
    firewall.interfaces."tailscale0".allowedTCPPorts = [22];
  };
  systemd.network = {
    networks = {
      "10-wired-default" = {
        matchConfig.Name = "en*";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "yes";
        };
      };
      "80-forward" = {
        matchConfig.Name = "wlp0s20f3";
        networkConfig.IPMasquerade = "both";
      };
    };
    wait-online.enable = false;
  };
  boot.initrd.systemd.network.wait-online.enable = false;

  persist = {
    enable = true;
    deviceService = "dev-nvme0n1p2.device";
    rootPath = "/dev/nvme0n1p2";
  };

  users.users = {
    nikodem = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/nikodem/password".path;
      extraGroups = ["wheel" "docker" "libvirtd"];
      shell = pkgs.fish;
      openssh.authorizedKeys.keyFiles = [
        ./user_nikodem_ssh_id_ed25519.pub
        ../../home/nm1/user_nm1_ssh_id_ed25519.pub
      ];
    };
  };

  services.printing = {
    enable = true;
    drivers = [pkgs.gutenprint];
  };

  services.syncthing.user = "nikodem";
}
