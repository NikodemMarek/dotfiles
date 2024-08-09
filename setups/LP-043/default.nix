{
  pkgs,
  config,
  ...
}: {
  imports = [
    ../../host
    ./hardware-configuration.nix

    (import ../../host/disko/device-btrfs-persistence.nix {
      device = "/dev/nvme0n1";
      swap = 38;
    })

    ../../host/impermanence.nix
    ../../host/hyprland.nix
    ../../host/docker.nix

    ../../host/battery-saver.nix
    ../../host/bluetooth.nix
    ../../host/openfortivpn.nix
    ./secrets.nix
  ];

  networking = {
    hostName = "LP-043";
    interfaces.ppp0.virtual = true;
    wireless.networks = {
      "SoftNet_CT" = {
        auth = ''
          key_mgmt=WPA-EAP
          eap=TLS
          identity="@IDENTITY_SoftNet_CT@"
          client_cert="${config.sops.secrets."users/nm1/openfortivpn/user_cert".path}"
          private_key="${config.sops.secrets."users/nm1/openfortivpn/user_key".path}"
          private_key_passwd="@PRIVATE_KEY_PASSWD_SoftNet_CT@"
        '';
        priority = 20;
      };
      "SoftNet".psk = "@PSK_SoftNet@";
    };
  };

  users.users = {
    nm1 = {
      isNormalUser = true;
      hashedPasswordFile = config.sops.secrets."users/nm1/password".path;
      extraGroups = ["wheel" "networkmanager" "docker" "openfortivpn"];
      shell = pkgs.fish;
      openssh.authorizedKeys.keyFiles = [
        ../desktop/users/nikodem/id_ed25519.pub
        ../laptop/users/nikodem/id_ed25519.pub
        ../LP-043/users/nm1/id_ed25519.pub
      ];
    };
  };

  environment.systemPackages = [pkgs.cifs-utils];

  boot.kernelParams = ["resume_offset=533760"];

  fileSystems."/mnt/softnet_fs" = {
    device = "//fs.corp.softnet.com.pl/home/nm1";
    fsType = "cifs";
    options = let
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
    in ["${automount_opts},credentials=/etc/nixos/smb-secrets"];
  };
}
