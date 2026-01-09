{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix

    (import ../features/disko/btrfs-persistence-swapfile.nix {
      device = "/dev/nvme0n1";
      swap = 15;
    })

    ../features
    ../features/optional/stylix.nix
    ../features/optional/systemd-boot.nix
    ../features/optional/battery-saver.nix
    ../features/optional/bluetooth.nix
    ../features/optional/pipewire.nix
    ../features/optional/libvirt.nix
    ../features/optional/syncthing.nix
    ../features/optional/docker.nix

    ./init.nix
    ./persist.nix
    ./networking
  ];

  networking.hostName = "yenn";
  time.timeZone = "Europe/Warsaw";

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

  sops.secrets = {
    "users/nikodem/password" = {
      neededForUsers = true;
    };
    "users/nikodem/ssh_id_ed25519" = {
      mode = "0400";
      owner = "nikodem";
      group = "users";
      path = "/home/nikodem/.ssh/id_ed25519";
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/nikodem/.ssh 0700 nikodem users -"
    "L+ /home/nikodem/.ssh/id_ed25519.pub 0400 nikodem users - ${./user_nikodem_ssh_id_ed25519.pub}"
  ];

  services.printing = {
    enable = true;
    drivers = [pkgs.gutenprint];
  };

  services.syncthing.user = "nikodem";
}
