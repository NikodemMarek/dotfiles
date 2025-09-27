{config, ...}: {
  networking.firewall.allowedTCPPorts = [80 443];

  services.traefik = {
    enable = true;

    staticConfigOptions = {
      entryPoints = {
        web = {
          address = ":80";
          asDefault = true;
          # http.redirections.entrypoint = {
          #   to = "websecure";
          #   scheme = "https";
          # };
        };

        websecure = {
          address = ":443";
          asDefault = true;
          # http.tls.certResolver = "letsencrypt";
        };

        metrics = {
          address = ":8013";
        };
      };

      # certificatesResolvers.letsencrypt.acme = {
      #   email = "postmaster@YOUR.DOMAIN";
      #   storage = "${config.services.traefik.dataDir}/acme.json";
      #   httpChallenge.entryPoint = "web";
      # };

      api.dashboard = true;
      api.insecure = true;

      log = {
        level = "INFO";
        filePath = "${config.services.traefik.dataDir}/traefik.log";
        noColor = false;
        compress = true;
      };
      metrics.prometheus = {
        entryPoint = "metrics";
      };
    };

    dynamicConfigOptions.http = {
      services.traefik.loadBalancer.servers = [
        {
          url = "http://127.0.0.1:8080";
        }
      ];
      routers.traefik = {
        entryPoints = ["web"];
        rule = "Host(`traefik.net`)";
        service = "traefik";
        # tls.certResolver = "letsencrypt";
      };
    };
  };
}
