{
  pkgs,
  config,
  ...
}: let
  readIfExists = path:
    if builtins.pathExists path
    then builtins.readFile path
    else null;
in {
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix

    (import ../features/disko/device-btrfs-persistence.nix {
      device = "nvme0n1";
      swap = 38;
    })

    ../features
    ../features/optional/battery-saver.nix
    ../features/optional/bluetooth.nix
    ../features/optional/openfortivpn.nix

    ../../home/nm1/persist.nix
  ];

  boot.kernel.sysctl = {"fs.file-max" = 524288;};
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "-";
      item = "nofile";
      value = "524288";
    }
  ];

  networking = {
    hostName = "LP-043";
    extraHosts = readIfExists config.sops.secrets."network/hosts".path;
    interfaces.ppp0.virtual = true;
    wireless.networks = {
      "SoftNet_CT" = {
        auth = ''
          key_mgmt=WPA-EAP
          eap=TLS
          identity="ext:IDENTITY_SoftNet_CT"
          client_cert="${config.sops.secrets."users/nm1/openfortivpn/user_cert".path}"
          private_key="${config.sops.secrets."users/nm1/openfortivpn/user_key".path}"
          private_key_passwd="ext:PRIVATE_KEY_PASSWD_SoftNet_CT"
        '';
        priority = 20;
      };
      "SoftNet".psk = "ext:PSK_SoftNet";
    };
  };

  persist = {
    enable = true;
    deviceService = "dev-root_vg-root.device";
    rootPath = "/dev/root_vg/root";
  };

  users.users = {
    nm1 = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/nm1/password".path;
      extraGroups = ["wheel" "docker" "openfortivpn"];
      shell = pkgs.fish;
      openssh.authorizedKeys.keyFiles = [
        ./user_nm1_ssh_id_ed25519.pub
        ../desktop/user_nikodem_ssh_id_ed25519.pub
        ../laptop/user_nikodem_ssh_id_ed25519.pub
      ];
    };
  };

  # services.syncthing = {
  #   enable = true;
  #   openDefaultPorts = false;
  #   key = config.sops.secrets."syncthing/key".path;
  #   cert = config.sops.secrets."syncthing/cert".path;
  #   overrideDevices = true;
  #   overrideFolders = true;
  #   user = "nikodem";
  #   group = "users";
  #   dataDir = "${config.users.users.nikodem.home}/.local/share/syncthing";
  #   configDir = "${config.users.users.nikodem.home}/.config/syncthing";
  #   settings = {
  #     devices = {
  #       "pixel-6a".id = "L7IXLIC-DU3D4MJ-OVOXKBW-D5M2AW5-3JWOFF4-X43JUPT-JN3XWZL-2FNL6QT";
  #       "tablet".id = "SCFNK0Z-UDF56C2-26ZS36D-A2PNTWO-K06IC55-0QGWCTN-MLNQBND-PXD8JQX";
  #     };
  #     folders = {
  #       "obsidian" = {
  #         path = "${config.users.users.nikodem.home}/vaults/main";
  #         devices = ["pixel-6a" "tablet"];
  #         copyOwnershipFromParent = true;
  #         versioning = {
  #           type = "simple";
  #           params = {
  #             keep = "5";
  #           };
  #         };
  #       };
  #     };
  #   };
  # };
}
