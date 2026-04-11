{config, ...}: {
  sops.secrets = {
    "k3s/token" = {};
  };

  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.sops.secrets."k3s/token".path;
    clusterInit = true;
    extraFlags = toString [
      "--flannel-iface=eth0"
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
}
