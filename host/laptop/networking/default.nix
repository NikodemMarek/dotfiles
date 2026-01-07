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

  sops.secrets."wpa_supplicant/config" = {
    sopsFile = ./wpa_config.conf;
    format = "binary";
  };
  environment.etc = {
    "wpa_supplicant/agh_ca.pem".source = ./agh_ca.pem;
  };

  networking.wireless = {
    enable = true;
    userControlled.enable = true;
    extraConfigFiles = [config.sops.secrets."wpa_supplicant/config".path];
  };
}
