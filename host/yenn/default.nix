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
    ../features/optional/stylix.nix
    ../features/optional/systemd-boot.nix
    ../features/optional/home-manager.nix
    ../features/optional/battery-saver.nix
    ../features/optional/bluetooth.nix
    ../features/optional/pipewire.nix
    ../features/optional/libvirt.nix
    ../features/optional/syncthing.nix
    ../features/optional/docker.nix

    ../../home/nikodem/persist.nix
    ./init.nix
    ./networking
  ];

  environment.systemPackages = [
    pkgs.wrapped.zellij
    pkgs.alacritty
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

  services.printing = {
    enable = true;
    drivers = [pkgs.gutenprint];
  };

  services.syncthing.user = "nikodem";
}
