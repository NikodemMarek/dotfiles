{config, ...}: {
  services.cloudflared = {
    enable = true;
    tunnels = {
      "server" = {
        credentialsFile = "${config.sops.secrets."cloudflared_creds".path}";
        certificateFile = "${config.sops.secrets."cloudflared_cert".path}";
        default = "http_status:404";
        edgeIPVersion = "6";
      };
    };
  };
}
