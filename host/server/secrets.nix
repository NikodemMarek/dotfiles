{
  imports = [];

  sops.secrets = {
    "host_ssh_ed25519_priv" = {};
    "users/maintenance/password" = {
      neededForUsers = true;
    };

    "cloudflared_cert" = {
      sopsFile = ./cloudflared_cert.pem;
      format = "binary";
    };
    "cloudflared_creds" = {
      sopsFile = ./cloudflared_creds.json.bin;
      format = "binary";
    };

    "matrix/registration_token" = {};
  };
}
