{pkgs, ...}: {
  imports = [
    (import ../modules/disko/device-btrfs-persistence.nix {
      device = "/dev/nvme0n1";
      swap = 38;
    })

    ../modules/impermanence.nix
    ../modules/sops.nix
    ../modules/hyprland.nix
    ../modules/docker.nix
    ../modules/dnscrypt-proxy2.nix
    ../modules/battery-saver.nix
    ../modules/bluetooth.nix
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
      format = "pem";
      mode = "0440";
      group = "users";
    };
    "openfortivpn/user_key" = {
      sopsFile = ./openfortivpn_key.pem;
      format = "pem";
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
