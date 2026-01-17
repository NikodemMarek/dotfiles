{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.hardware.nixosModules.framework-amd-ai-300-series

    (import ../features/disko/luks-btrfs-persistence-swapfile.nix {
      device = "/dev/nvme0n1";
      swap = 24;
    })

    ../features
    ../features/optional/stylix.nix
    ../features/optional/systemd-boot.nix
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

  nixpkgs.hostPlatform.system = "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = true;
  powerManagement.cpuFreqGovernor = "ondemand";
  boot.initrd = {
    availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usb_storage"
      "sd_mod"
    ];
    kernelModules = ["kvm-amd"];
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
        command = "${pkgs.tuigreet}/bin/tuigreet -r -t";
      };
    };
  };
}
