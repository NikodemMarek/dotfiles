{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./host/features
    ./hardware-configuration.nix
    ./secrets.nix

    (import ../features/disko/device-btrfs-persistence.nix {
      device = "nvme0n1";
      swap = 38;
    })
    (import ../features/disko/btrfs-single-partition.nix {
      device = "sda";
    })

    ../../home/nikodem/persist.nix
  ];

  networking = {
    hostName = "desktop";
    interfaces.enp5s0.wakeOnLan.enable = true;
  };

  persist = {
    enable = true;
    deviceService = "dev-root_vg-root.device";
    rootPath = "/dev/root_vg/root";
  };

  users.users = {
    nikodem = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/nikodem/password".path;
      extraGroups = ["wheel" "docker"];
      shell = pkgs.fish;
      openssh.authorizedKeys.keyFiles = [
        ./user_nikodem_ssh_id_ed25519.pub
        ../laptop/user_nikodem_ssh_id_ed25519.pub
        ../LP-043/user_nm1_ssh_id_ed25519.pub
        ../LP-043/user_nikodem_ssh_id_ed25519.pub
      ];
    };
  };

  # TODO: Migrate to home-manager when it gets support
  services.syncthing = {
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
}
