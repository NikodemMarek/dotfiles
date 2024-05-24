{
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
    rootless = {
      enable = false;
      setSocketVariable = true;
    };
  };
}
