{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.beets
  ];

  systemd.tmpfiles.rules = [
    "L+ /home/maintenance/.config/beets/config.yaml - - - - ${./beets.yaml}"
  ];

  persist.generated.directories = [
    {
      directory = "/var/lib/music/beets";
      user = "maintenance";
      group = "music";
      mode = "740";
    }
  ];
}
