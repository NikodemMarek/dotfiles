{
  sops.secrets.networks = {
    sopsFile = ./networks.env;
    format = "dotenv";
  };
}
