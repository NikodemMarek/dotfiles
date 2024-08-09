{
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
    rootless = {
      enable = false;
      setSocketVariable = true;
    };
  };

  systemd.network.networks = {
    "0-docker0" = {
      matchConfig.Name = "docker0";
      linkConfig = {
        Unmanaged = true;
      };
    };
    "0-docker-br" = {
      matchConfig.Name = "br-*";
      linkConfig = {
        Unmanaged = true;
      };
    };
  };
}
