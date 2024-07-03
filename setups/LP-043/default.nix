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
  ];

  networking = {
    hostName = "LP-043";
    wireless.networks."SoftNet".psk = "@PSK_SoftNet@";
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

  sops.secrets = {
    "users/nm1/openfortivpn/host" = {};
    "users/nm1/openfortivpn/port" = {};
    "users/nm1/openfortivpn/username" = {};
    "users/nm1/openfortivpn/password" = {};
    "users/nm1/openfortivpn/realm" = {};
    "users/nm1/openfortivpn/trusted_cert" = {};
    "users/nm1/openfortivpn/user_cert" = {
      sopsFile = ./openfortivpn_cert.pem;
      format = "binary";
    };
    "users/nm1/openfortivpn/user_key" = {
      sopsFile = ./openfortivpn_key.pem;
      format = "binary";
    };
  };

  environment.systemPackages = [pkgs.cifs-utils];

  fileSystems."/mnt/softnet_fs" = {
    device = "//fs.corp.softnet.com.pl/home/nm1";
    fsType = "cifs";
    options = let
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
    in ["${automount_opts},credentials=/etc/nixos/smb-secrets"];
  };

  settings = {
    monitors = [
      {
        name = "eDP-1";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        x = 0;
        y = 0;
        transform = 0;
      }
      {
        name = "DP-3";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        x = 0;
        y = -1080;
        transform = 0;
      }
      {
        name = "DP-4";
        width = 1920;
        height = 1080;
        refreshRate = 60;
        x = 1920;
        y = -1260;
        transform = 3;
      }
    ];
  };
}
