{
  lib,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix

    ../features
    ../features/optional/systemd-boot.nix
    ../features/optional/tailscale.nix
    ../features/optional/maintenance.nix
    ../features/optional/k3s.nix

    ./nfs.nix
  ];

  networking.hostName = "regis";

  time.timeZone = "Europe/Warsaw";

  persist = {
    enable = true;
    deviceService = "dev-nvme0n1p2.device";
    rootPath = "/dev/nvme0n1p2";
    isCrypted = true;
    isZfs = true;
  };

  systemd.network = {
    links = {
      "10-rename-enp2s0" = {
        matchConfig.MACAddress = "6c:bf:b5:05:77:88";
        linkConfig = {Name = "eth0";};
      };
      "10-rename-enp3s0" = {
        matchConfig.MACAddress = "6c:bf:b5:05:77:89";
        linkConfig = {Name = "eth1";};
      };
    };
    networks = {
      "10-ethernet" = {
        matchConfig.Type = "ether";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "yes";
        };
        linkConfig.RequiredForOnline = "no";
      };
    };
    wait-online.enable = false;
  };

  boot.initrd.network = {
    enable = true;
    ssh = {
      enable = true;
      port = 2222;
      authorizedKeyFiles = [../yenn/user_nikodem_ssh_id_ed25519.pub];
      hostKeys = [config.sops.secrets."host_ssh_ed25519_priv".path];
    };
  };

  services.k3s = {
    role = "agent";
    serverAddr = "https://100.97.10.25:6443";
    extraFlags = toString [
      "--kube-proxy-arg=proxy-mode=nftables"
      "--vpn-auth-file=${config.sops.templates."k3s-vpn-auth".path}"
      "--node-external-ip=100.109.230.83"
    ];
  };
}
