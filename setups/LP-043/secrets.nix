{
  sops.secrets = {
    "users/nm1/openfortivpn/host" = {};
    "users/nm1/openfortivpn/port" = {};
    "users/nm1/openfortivpn/username" = {};
    "users/nm1/openfortivpn/password" = {};
    "users/nm1/openfortivpn/realm" = {};
    "users/nm1/openfortivpn/trusted_cert" = {};
    "users/nm1/openfortivpn/user_cert" = {
      sopsFile = ./openfortivpn_cert.pem;
      format = "binary";
    };
    "users/nm1/openfortivpn/user_key" = {
      sopsFile = ./openfortivpn_key.pem;
      format = "binary";
    };
    "users/nm1/m2_settings" = {
      sopsFile = ./m2_settings.xml;
      format = "binary";
    };
    "users/nm1/npm/url" = {};
    "users/nm1/npm/username" = {};
    "users/nm1/npm/password" = {};
  };
}
