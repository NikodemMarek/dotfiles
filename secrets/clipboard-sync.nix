{
  sops.secrets = {
    "clipboard-sync/client-key" = {
      sopsFile = ./clipboard-sync-key.pem;
      format = "binary";
    };
  };
}
