{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix

    (import ../features/disko/device-btrfs-persistence.nix {
      device = "nvme0n1";
      swap = 38;
    })

    ../features/multi-user.nix
    ../features/hyprland.nix
    ../features/docker.nix
    ../features/zerotier.nix

    ../features/battery-saver.nix
    ../features/bluetooth.nix
    ../features/openfortivpn.nix

    ../../home/nm1/persist.nix
    ../../home/nikodem/persist.nix
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
      extraGroups = ["wheel" "networkmanager" "docker" "openfortivpn"];
      shell = pkgs.fish;
      openssh.authorizedKeys.keyFiles = [
        ./user_nm1_ssh_id_ed25519.pub
        ../desktop/user_nikodem_ssh_id_ed25519.pub
        ../laptop/user_nikodem_ssh_id_ed25519.pub
      ];
    };
    nikodem = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/nikodem/password".path;
      extraGroups = ["wheel" "docker"];
      shell = pkgs.fish;
      openssh.authorizedKeys.keyFiles = [
        ./user_nm1_ssh_id_ed25519.pub
        ../desktop/user_nikodem_ssh_id_ed25519.pub
        ../laptop/user_nikodem_ssh_id_ed25519.pub
      ];
    };
  };
}
