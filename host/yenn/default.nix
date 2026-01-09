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

    ./networking
    ./nikodem.nix
  ];

  networking.hostName = "yenn";
  time.timeZone = "Europe/Warsaw";

  persist = {
    enable = true;
    deviceService = "dev-nvme0n1p2.device";
    rootPath = "/dev/nvme0n1p2";
  };

  sops.secrets = {
    "users/nikodem/password" = {
      neededForUsers = true;
    };
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

  security.rtkit.enable = true;
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --cmd Hyprland -r -t";
      };
    };
  };
}
