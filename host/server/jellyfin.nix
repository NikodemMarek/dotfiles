let
  jellyfinIp = "20.0.0.100";
in {
  networking.interfaces."br0" = {
    virtual = true;
    ipv4.addresses = [
      {
        address = "20.0.0.1";
        prefixLength = 24;
      }
    ];
  };

  containers.jellyfin = {
    autoStart = true;
    privateNetwork = true;
    localAddress = jellyfinIp;
    config = {
      pkgs,
      lib,
      ...
    }: {
      system.stateVersion = "23.11";

      networking = {
        firewall.enable = true;
        # Use systemd-resolved inside the container
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        useHostResolvConf = lib.mkForce false;
      };

      services.resolved.enable = true;

      services.jellyfin = {
        enable = true;
        openFirewall = true;
      };

      environment.systemPackages = [
        pkgs.jellyfin
        pkgs.jellyfin-web
        pkgs.jellyfin-ffmpeg
      ];
    };
  };

  services = {
    jellyfin = {
      enable = true;
    };

    traefik.dynamicConfigOptions.http = {
      services.jellyfin.loadBalancer.servers = [
        {
          url = "http://${jellyfinIp}:8096";
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
}
