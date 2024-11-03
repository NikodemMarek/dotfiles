{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix

    (import ../features/disko/device-btrfs-persistence.nix {
      device = "/dev/nvme0n1";
      swap = 38;
    })
    (import ../features/disko/btrfs-single-partition.nix {
      device = "/dev/sda";
    })

    ../features/hyprland.nix
    ../features/docker.nix
    ../features/dnscrypt-proxy2.nix
    ../features/zerotier.nix
    ../features/syncthing.nix
    ../features/ollama.nix
    ../features/virtualbox.nix
  ];

  networking.hostName = "desktop";

  persist = {
    enable = true;
    device = "nvme0n1p2";
  };

  users.users = {
    nikodem = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/nikodem/password".path;
      extraGroups = ["wheel" "docker" "music"];
      shell = pkgs.fish;
      openssh.authorizedKeys.keyFiles = [
        ./user_nikodem_ssh_id_ed25519.pub
        ../laptop/user_nikodem_ssh_id_ed25519.pub
        ../LP-043/user_nm1_ssh_id_ed25519.pub
      ];
    };
    fun = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/fun/password".path;
      extraGroups = ["wheel" "music"];
      shell = pkgs.fish;
    };
    ctf = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/ctf/password".path;
      extraGroups = ["wheel"];
      shell = pkgs.fish;
    };
  };

  boot.extraModulePackages = [config.boot.kernelPackages.rtl8821au];
  environment.systemPackages = with pkgs; [
    linuxKernel.packages.linux_6_1.rtl8821au
  ];

  services = {
    music = {
      enable = true;
      anysync = true;
      persistent = true;
    };
    # TODO: Migrate to home-manager when it gets support
    syncthing = {
      enable = true;
      openDefaultPorts = false;
      key = config.sops.secrets."syncthing/key".path;
      cert = config.sops.secrets."syncthing/cert".path;
      overrideDevices = true;
      overrideFolders = true;
      user = "nikodem";
      group = "users";
      dataDir = "${config.users.users.nikodem.home}/.local/share/syncthing";
      configDir = "${config.users.users.nikodem.home}/.config/syncthing";
      settings = {
        devices = {
          "pixel-6a".id = "L7IXLIC-DU3D4MJ-OVOXKBW-D5M2AW5-3JWOFF4-X43JUPT-JN3XWZL-2FNL6QT";
          "tablet".id = "SCFNK0Z-UDF56C2-26ZS36D-A2PNTWO-K06IC55-0QGWCTN-MLNQBND-PXD8JQX";
        };
        folders = {
          "obsidian" = {
            path = "${config.users.users.nikodem.home}/vaults/main";
            devices = ["pixel-6a" "tablet"];
            copyOwnershipFromParent = true;
            versioning = {
              type = "simple";
              params = {
                keep = "5";
              };
            };
          };
        };
      };
    };
  };

  users.extraGroups.vboxusers.members = ["nikodem"];
}
