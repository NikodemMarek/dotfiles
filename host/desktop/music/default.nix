{
  imports = [
    ./management.nix
  ];

  services.traefik.dynamicConfigOptions.http = {
    routers = {
      subsonic = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^subsonic\..+$`)";
        service = "web-forward";
        # tls.certResolver = "letsencrypt";
      };
    };
  };
}
