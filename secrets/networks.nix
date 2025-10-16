{
  sops.secrets = {
    networks = {
      sopsFile = ./networks.env;
      format = "dotenv";
    };
    "wpa_supplicant/eduroam" = {
      sopsFile = ./wpa_supplicant_eduroam.conf;
      format = "binary";
    };
  };
}
