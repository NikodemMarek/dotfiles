{config, ...}: {
  sops.secrets = {
    "k3s/token" = {};
  };

  services.openiscsi = {
    enable = true;
    name = "${config.networking.hostName}-initiatorhost";
  };
  systemd.services.iscsid.serviceConfig = {
    PrivateMounts = "yes";
    BindPaths = "/run/current-system/sw/bin:/bin";
  };

  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.sops.secrets."k3s/token".path;
    clusterInit = true;
    extraFlags = toString [
      "--kube-proxy-arg=proxy-mode=nftables"
      "--disable-network-policy"
      "--flannel-backend=vxlan"
      "--flannel-iface=eth0"

      "--disable=traefik"
    ];
  };

  persist.generated.directories = [
    {
      directory = "/var/lib/rancher/k3s";
      user = "root";
      group = "root";
      mode = "755";
    }
    {
      directory = "/var/lib/kubelet";
      user = "root";
      group = "root";
      mode = "755";
    }
  ];

  networking.firewall = {
    allowedTCPPorts = [6443];
    allowedUDPPorts = [8472 53];

    checkReversePath = "loose";

    trustedInterfaces = ["cni0" "flannel.1"];
  };

  systemd.network.networks."10-k3s-interfaces" = {
    matchConfig.Name = "veth*";
    linkConfig.Unmanaged = true;
  };
}
