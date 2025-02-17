{config, ...}: {
  sops.secrets."nextcloud/adminpass" = {
    mode = "0444";
  };

  containers.nextcloud = let
    adminpassFile = config.sops.secrets."nextcloud/adminpass".path;
  in {
    autoStart = true;
    privateNetwork = false;
    forwardPorts = [
      {
        protocol = "tcp";
        hostPort = 80;
        containerPort = 5080;
      }
      {
        protocol = "tcp";
        hostPort = 443;
        containerPort = 5443;
      }
    ];
    config = {
      config,
      pkgs,
      lib,
      ...
    }: {
      services.nextcloud = {
        enable = true;
        package = pkgs.nextcloud28;
        hostName = "localhost";
        config.adminpassFile = adminpassFile;
        datadir = "/mnt/data";
      };

      system.stateVersion = "23.11";

      networking = {
        firewall = {
          enable = true;
          allowedTCPPorts = [80];
        };
        useHostResolvConf = lib.mkForce false;
      };

      services.resolved.enable = true;
    };
  };
}
