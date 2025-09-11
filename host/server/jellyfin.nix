{pkgs, ...}: {
  services.jellyfin = {
    enable = true;

    traefik = {
      dynamicConfigOptions = {
        http = {
          services = {
            jellyfin.loadBalancer.servers = [
              {
                url = "http://localhost:8096";
              }
            ];
          };

          routers = {
            jellyfin = {
              entryPoints = ["websecure"];
              rule = "Host(`jellyfin.nprox.dev`)";
              service = "jellyfin";
              # tls.certResolver = "letsencrypt";
            };
          };
        };
      };
    };
  };

  environment.systemPackages = [
    pkgs.jellyfin
    pkgs.jellyfin-web
    pkgs.jellyfin-ffmpeg
  ];
}
