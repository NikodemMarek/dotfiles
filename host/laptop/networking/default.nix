{config, ...}: {
  imports = [
    ../../features/optional/tailscale.nix
    ../../features/optional/zerotier.nix
  ];

  networking = {
    bridges."br0".interfaces = ["wlp0s20f3"];
    nat.externalInterface = "wlp0s20f3";
    firewall.interfaces."tailscale0".allowedTCPPorts = [22];
  };

  systemd.network = {
    networks = {
      "10-wired-default" = {
        matchConfig.Name = "en*";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "yes";
        };
      };
      "20-wireless-default" = {
        matchConfig.Name = "wl*";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "yes";
          IgnoreCarrierLoss = "3s";
        };
      };
      "80-forward" = {
        matchConfig.Name = "wlp0s20f3";
        networkConfig.IPMasquerade = "both";
      };
    };
    wait-online.enable = false;
  };
  boot.initrd.systemd.network.wait-online.enable = false;

  environment.etc = {
    "wpa_supplicant/agh_ca.pem".source = ./agh_ca.pem;
  };

  networking.wireless = {
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
}
