{
  config,
  pkgs,
  ...
}: {
  imports = [
    # ../features
    ./hardware-configuration.nix
    ./secrets.nix

    (import ../features/disko/device-btrfs-persistence.nix {
      device = "nvme0n1";
      swap = 38;
    })
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
    # interfaces.enp5s0.wakeOnLan.enable = true;
  };

  persist = {
    enable = true;
    deviceService = "dev-root_vg-root.device";
    rootPath = "/dev/root_vg/root";
  };

  users.user = {
    root = {
      password = "1234";
      openssh.authorizedKeys.keyFiles = [
        ../laptop/user_nikodem_ssh_id_ed25519.pub
        ../../home/nm1/user_nm1_ssh_id_ed25519.pub
      ];
    };
    # nikodem = {
    #   isNormalUser = true;
    #   # hashedPasswordFile = config.sops.secrets."users/nikodem/password".path;
    #   password = "1234";
    #   extraGroups = ["wheel" "docker"];
    #   shell = pkgs.fish;
    #   openssh.authorizedKeys.keyFiles = [
    #     ../laptop/user_nikodem_ssh_id_ed25519.pub
    #   ];
    # };
  };
}
