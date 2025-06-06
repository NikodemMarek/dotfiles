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
    extraHosts = ''
      # local dorm network
      192.168.10.10 dorm.desktop
      192.168.10.20 dorm.laptop
      192.168.10.60 dorm.LP-043

      # zerotier network
      192.168.192.10 zerotier.desktop
      192.168.192.20 zerotier.laptop
      192.168.192.60 zerotier.LP-043
    '';
    wireless = lib.mkIf ((builtins.hasAttr "networks" config.sops.secrets) && (builtins.pathExists config.sops.secrets.networks.path)) {
      enable = true;
      userControlled.enable = true;
      secretsFile = config.sops.secrets.networks.path;
      networks = {
        "AGH-Guest" = {};
        "Meshki56".pskRaw = "ext:PSK_Meshki56";
        "402a".pskRaw = "ext:PSK_402a";
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
