{
  lib,
  config,
  ...
}: {
  systemd.network = {
    enable = true;
    networks = {
      "10-wired-default" = {
        matchConfig.Name = "en*";
        networkConfig = {
          DHCP = "ipv4";
        };
      };
      "20-wireless-default" = {
        matchConfig.Name = "wl*";
        networkConfig = {
          DHCP = "ipv4";
          IgnoreCarrierLoss = "3s";
        };
      };
    };
  };

  networking = {
    useNetworkd = true;
    wireless = lib.mkIf ((builtins.hasAttr "networks" config.sops.secrets) && (builtins.pathExists config.sops.secrets.networks.path)) {
      enable = true;
      userControlled.enable = true;
      secretsFile = config.sops.secrets.networks.path;
      networks = {
        "AGH-Guest" = {};
        "Meshki56".pskRaw = "ext:PSK_Meshki56";
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

    nftables.enable = true;
    firewall.enable = true;
  };
}
