{
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

    ./proxy.nix
    ./jellyfin.nix
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
    hostName = "desktop";
    firewall.allowedTCPPorts = [22];
    # interfaces.enp5s0.wakeOnLan.enable = true;
  };

  persist = {
    enable = true;
    deviceService = "dev-nvme0n1p2.device";
    rootPath = "/dev/nvme0n1p2";
  };

  users.users = {
    root = {
      password = "1234";
      openssh.authorizedKeys.keyFiles = [
        ../laptop/user_nikodem_ssh_id_ed25519.pub
        ../../home/nm1/user_nm1_ssh_id_ed25519.pub
      ];
    };
  };
}
