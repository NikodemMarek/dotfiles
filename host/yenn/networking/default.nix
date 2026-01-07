{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../features/optional/tailscale.nix
    ../../features/optional/zerotier.nix
  ];

  networking = {
    bridges."br0".interfaces = ["wlan0"];
    nat.externalInterface = "wlan0";
    firewall.interfaces."tailscale0".allowedTCPPorts = [22];
  };

  systemd.network = {
    links = {
      "10-wired-random-mac" = {
        matchConfig = {
          Type = "ether";
          Kind = "!*";
        };
        linkConfig = {MACAddressPolicy = "random";};
      };
      "10-wireless-random-mac" = {
        matchConfig = {Type = "wlan";};
        linkConfig = {MACAddressPolicy = "random";};
      };
    };
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
        matchConfig.Name = "wlan0";
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

  systemd.services.macchanger = let
    change-mac = pkgs.writeShellScript "change-mac" ''
      card=$1
      tmp=$(mktemp)
      ${pkgs.macchanger}/bin/macchanger "$card" -s | grep -oP "[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[^ ]*" > "$tmp"
      mac1=$(cat "$tmp" | head -n 1)
      mac2=$(cat "$tmp" | tail -n 1)
      if [ "$mac1" = "$mac2" ]; then
      	if [ "$(cat /sys/class/net/"$card"/operstate)" = "up" ]; then
      		${pkgs.iproute2}/bin/ip link set "$card" down &&
      		${pkgs.macchanger}/bin/macchanger -r "$card"
      		${pkgs.iproute2}/bin/ip link set "$card" up
      	else
      		${pkgs.macchanger}/bin/macchanger -r "$card"
      	fi
      fi
    '';
  in {
    enable = true;
    description = "macchanger on wlan0";
    wants = ["network-pre.target"];
    before = ["network-pre.target"];
    bindsTo = ["sys-subsystem-net-devices-wlan0.device"];
    after = ["sys-subsystem-net-devices-wlan0.device"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${change-mac} wlan0";
    };
  };
}
