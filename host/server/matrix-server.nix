{
  inputs,
  pkgs,
  config,
  ...
}: let
  tuwunelPort = 6167;
in {
  sops.secrets."matrix/registration_token" = {
    restartUnits = ["container@matrix.service"];
  };

  containers.matrix = {
    autoStart = true;
    privateNetwork = false;
    forwardPorts = [
      {
        containerPort = 2283;
        hostPort = tuwunelPort;
        protocol = "tcp";
      }
    ];
    extraFlags = ["--load-credential=registration_token_file:${config.sops.secrets."matrix/registration_token".path}"];
    config = {lib, ...}: {
      services.matrix-tuwunel = {
        enable = true;
        package = inputs.tuwunel.packages.${pkgs.stdenv.hostPlatform.system}.default;
        user = "root";
        settings = {
          global = {
            port = [6167];
            server_name = "nkmrk.com";
            allow_federation = true;
            allow_encryption = true;
            allow_registration = true;
            # FIXME: File does not work, because of tuwunel bug?
            # registration_token_file = "/run/credentials/@system/registration_token_file";
          };
        };
      };

      system.stateVersion = "25.11";

      networking = {
        firewall.enable = true;
        useHostResolvConf = lib.mkForce false;
      };

      services.resolved.enable = true;
    };
  };

  services.traefik.dynamicConfigOptions.http = {
    services = {
      matrix.loadBalancer.servers = [
        {
          url = "http://localhost:${toString tuwunelPort}";
        }
      ];
    };
    routers = {
      matrix = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^matrix\..+$`)";
        service = "matrix";
        # tls.certResolver = "letsencrypt";
      };
    };
  };
}
