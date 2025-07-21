{config, ...}: {
  services.clipboard-sync = {
    enable = true;
    autostart = true;
    config = {
      client_key = config.sops.secrets."clipboard-sync/client-key".path;
      peers_keys = [./clipboard-sync-peers-key.pem];
    };
  };
}
