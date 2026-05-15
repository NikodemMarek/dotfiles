{
  config,
  pkgs,
  ...
}: {
  sops.secrets = {
    "k3s/token" = {};
  };

  environment.systemPackages = [
    pkgs.sops
    pkgs.age
    pkgs.nfs-utils
  ];

  services.openiscsi = {
    enable = true;
    name = "${config.networking.hostName}-initiatorhost";
  };
  systemd.services.iscsid.serviceConfig = {
    PrivateMounts = "yes";
    BindPaths = "/run/current-system/sw/bin:/bin";
  };
  systemd.tmpfiles.rules = [
    "d /run/flannel 0755 root root -"
  ];

  services.k3s = {
    enable = true;
    tokenFile = config.sops.secrets."k3s/token".path;
  };

  systemd.services.k3s = {
    after = ["tailscaled.service"];
    wants = ["tailscaled.service"];
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
    {
      directory = "/var/lib/longhorn";
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
