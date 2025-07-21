{
  services.zerotierone = {
    enable = true;
    joinNetworks = [
      "6ab565387a704125"
    ];
  };

  persist.generated.directories = [
    "/var/lib/zerotier-one"
  ];
}
