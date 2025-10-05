{config, ...}: {
  # Theoretically docs say that those ports should be opened, but it seems to work without it.
  # networking.firewall = {
  #   allowedTCPPorts = [7844];
  #   allowedUDPPorts = [7844];
  # };

  services.cloudflared = {
    enable = true;
    tunnels = {
      "server" = {
        credentialsFile = "${config.sops.secrets."cloudflared_creds".path}";
        certificateFile = "${config.sops.secrets."cloudflared_cert".path}";
        ingress = {
          "*.nkmrk.com" = "http://localhost:80";
        };
        default = "http_status:404";
        edgeIPVersion = "auto";
      };
    };
  };
}
