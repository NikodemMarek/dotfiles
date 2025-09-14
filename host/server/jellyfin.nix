{pkgs, ...}: {
  services = {
    jellyfin.enable = true;
    traefik.dynamicConfigOptions.http = {
      services.jellyfin.loadBalancer.servers = [
        {
          url = "http://127.0.0.1:8096";
        }
      ];
      routers.jellyfin = {
        entryPoints = ["web"];
        rule = "Host(`jellyfin.nprox.local`)";
        service = "jellyfin";
        # tls.certResolver = "letsencrypt";
      };
    };
  };

  environment.systemPackages = [
    pkgs.jellyfin
    pkgs.jellyfin-web
    pkgs.jellyfin-ffmpeg
  ];
}
