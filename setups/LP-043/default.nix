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
  ];

  networking.hostName = "LP-043";

  sops.secrets = {
    "openfortivpn/host" = {
      sopsFile = ./secrets.yaml;
      mode = "0440";
      group = "users";
    };
    "openfortivpn/port" = {
      sopsFile = ./secrets.yaml;
      mode = "0440";
      group = "users";
    };
    "openfortivpn/username" = {
      sopsFile = ./secrets.yaml;
      mode = "0440";
      group = "users";
    };
    "openfortivpn/password" = {
      sopsFile = ./secrets.yaml;
      mode = "0440";
      group = "users";
    };
    "openfortivpn/realm" = {
      sopsFile = ./secrets.yaml;
      mode = "0440";
      group = "users";
    };
    "openfortivpn/trusted_cert" = {
      sopsFile = ./secrets.yaml;
      mode = "0440";
      group = "users";
    };
    "openfortivpn/user_cert" = {
      sopsFile = ./openfortivpn_cert.pem;
      format = "binary";
      mode = "0440";
      group = "users";
    };
    "openfortivpn/user_key" = {
      sopsFile = ./openfortivpn_key.pem;
      format = "binary";
      mode = "0440";
      group = "users";
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
