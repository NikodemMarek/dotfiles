{
  services.navidrome = {
    enable = true;
    group = "music";
    openFirewall = true;
    settings = {
      Port = 4533;
      Address = "0.0.0.0";
      EnableInsightsCollector = false;
      MusicFolder = "/mnt/music";
    };
  };
}
