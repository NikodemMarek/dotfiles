{
  pkgs,
  lib,
  config,
  ...
}: {
  systemd.network = {
    enable = true;
    networks = {
      "20-wireless-default" = {
        matchConfig.Name = "wl*";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "yes";
          IgnoreCarrierLoss = "3s";
        };
      };
    };
  };

  environment.etc = {
    "wpa_supplicant/agh_ca.pem".source = ./agh_ca.pem;
  };

  networking = {
    wireless = lib.mkIf ((builtins.hasAttr "networks" config.sops.secrets) && (builtins.pathExists config.sops.secrets.networks.path)) {
      enable = true;
      userControlled.enable = true;
      secretsFile = config.sops.secrets.networks.path;
      extraConfigFiles = [config.sops.secrets."wpa_supplicant/eduroam".path];
      networks = {
        "AGH-Guest" = {
          priority = -5;
        };
        "Meshki56".pskRaw = "ext:PSK_Meshki56";
        "studenciaki".pskRaw = "ext:PSK_studenciaki";
        "2hot2spot" = {
          pskRaw = "ext:PSK_2hot2spot";
          priority = -20;
        };
        "hot_pot" = {
          pskRaw = "ext:PSK_hot_pot";
          priority = -10;
        };
      };
    };
  };
}
