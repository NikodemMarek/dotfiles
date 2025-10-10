{
  inputs,
  config,
  ...
}: let
  tuwunelPort = 6167;
in {
  sops.secrets."matrix/registration_token" = {
    restartUnits = ["container@matrix.service"];
  };

  persist.generated.directories = [
    {
      directory = "/var/lib/matrix/tuwunel";
      user = "root";
      group = "root";
      mode = "770";
    }
  ];

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
    # bindMounts = {
    #   "/var/lib/tuwunel" = {
    #     hostPath = "/var/lib/matrix/tuwunel";
    #     isReadOnly = false;
    #   };
    # };
    extraFlags = ["--load-credential=registration_token_file:${config.sops.secrets."matrix/registration_token".path}"];
    config = {
      pkgs,
      lib,
      ...
    }: {
      imports = [
        ./matrix-server.nix
      ];

      services.matrix-tuwunel.package = inputs.tuwunel.packages.${pkgs.system}.default;

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
