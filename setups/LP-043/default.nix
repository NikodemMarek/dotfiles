{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix

    (import ../../host/disko/device-btrfs-persistence.nix {
      device = "/dev/nvme0n1";
      swap = 38;
    })
    (import ../../host/users.nix (import ./users.nix))

    ../../host
    ../../host/impermanence.nix
    ../../host/hyprland.nix
    ../../host/docker.nix
    ../../host/dnscrypt-proxy2.nix
    ../../host/battery-saver.nix
    ../../host/bluetooth.nix
    ../../host/openfortivpn.nix
  ];

  networking.hostName = "LP-043";
  systemd.network.networks."10-softnet-ethernet" = {
    matchConfig.Name = "enp0s13f0u2u1";
    networkConfig = {
      Description = "softnet ethernet";
      DHCP = "yes";
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
}
