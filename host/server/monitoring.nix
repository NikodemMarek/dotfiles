{config, ...}: {
  services = {
    prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 8011;
      scrapeConfigs = [
        {
          job_name = "traefik";
          static_configs = [
            {
              targets = ["127.0.0.1:8013"];
            }
          ];
        }
      ];
    };

    grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = 8012;
          enforce_domain = true;
          enable_gzip = true;
          domain = "grafana.nprox.local";
        };

        # Prevents Grafana from phoning home
        #analytics.reporting_enabled = false;
      };

      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "prometheus";
            type = "prometheus";
            url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
            isDefault = true;
            editable = false;
          }
        ];
      };
    };

    traefik.dynamicConfigOptions.http = {
      services = {
        grafana.loadBalancer.servers = [
          {
            url = "http://${toString config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}";
          }
        ];
        prometheus.loadBalancer.servers = [
          {
            url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
          }
        ];
      };
      routers = {
        grafana = {
          entryPoints = ["web"];
          rule = "Host(`grafana.nprox.local`)";
          service = "grafana";
          # tls.certResolver = "letsencrypt";
        };
        prometheus = {
          entryPoints = ["web"];
          rule = "Host(`prometheus.nprox.local`)";
          service = "prometheus";
          # tls.certResolver = "letsencrypt";
        };
      };
    };
  };
}
