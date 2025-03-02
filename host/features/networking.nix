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
        "308a_niezaliczan_semestranu".pskRaw = "ext:PSK_308a_niezaliczan_semestranu";
        "hot_pot" = {
          pskRaw = "ext:PSK_hot_pot";
          priority = -10;
        };
      };
    };

    nftables.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [22];
      allowedTCPPortRanges = [
        {
          from = 5000;
          to = 5999;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 5000;
          to = 5999;
        }
      ];
    };
  };
}
