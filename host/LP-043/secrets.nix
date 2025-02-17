{lib, ...}: {
  imports = [
    ../../secrets/api-keys.nix
  ];

  sops.secrets = {
    "users/nm1/ssh_id_ed25519" = {};

    networks = lib.mkForce {
      sopsFile = ./networks.env;
      format = "dotenv";
    };

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
    "users/nm1/gradle_properties" = {
      sopsFile = ./gradle_properties;
      format = "binary";
    };

    "users/nm1/npm/url" = {};
    "users/nm1/npm/username" = {};
    "users/nm1/npm/password" = {};
  };
}
