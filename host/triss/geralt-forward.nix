{
  services.traefik.dynamicConfigOptions.http = {
    services = {
      web-forward.loadBalancer.servers = [
        {
          url = "http://geralt:80";
        }
      ];
    };
    routers = {
      immich = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^immich\..+$`)";
        service = "web-forward";
        # tls.certResolver = "letsencrypt";
      };
      jellyfin = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^jellyfin\..+$`)";
        service = "web-forward";
        # tls.certResolver = "letsencrypt";
      };
      seerr = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^seerr\..+$`)";
        service = "web-forward";
        # tls.certResolver = "letsencrypt";
      };
      subsonic = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^subsonic\..+$`)";
        service = "web-forward";
        # tls.certResolver = "letsencrypt";
      };
    };
  };
}
