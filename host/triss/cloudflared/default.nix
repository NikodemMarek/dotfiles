{config, ...}: {
  # Theoretically docs say that those ports should be opened, but it seems to work without it.
  # networking.firewall = {
  #   allowedTCPPorts = [7844];
  #   allowedUDPPorts = [7844];
  # };

  sops.secrets = {
    "cloudflared_cert" = {
      sopsFile = ./cloudflared_cert.pem;
      format = "binary";
    };
    "cloudflared_creds" = {
      sopsFile = ./cloudflared_creds.json.bin;
      format = "binary";
    };
  };

  services.cloudflared = {
    enable = true;
    tunnels = {
      "triss" = {
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
