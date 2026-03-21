{config, ...}: {
  services.tailscale.enable = true;

  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];

  persist.generated.directories = [
    {
      directory = "/var/lib/tailscale";
      user = "root";
      group = "root";
      mode = "700";
    }
  ];

  networking = {
    firewall = {
      checkReversePath = "loose";
      trustedInterfaces = ["tailscale0"];
    };
    nftables.ruleset = ''
      table inet tailscale-filter {
        chain input {
          type filter hook input priority -10; policy accept;
          iifname "tailscale0" accept comment "Trusted Tailscale interface"
          ct state vmap { invalid : drop, established : accept, related : accept, new : jump input-allow, untracked : jump input-allow }
        }

        chain input-allow {
          iifname "tailscale0" tcp dport { 22, 80, 443, 2049, 7878, 8989, 8686, 8787, 9696, 6969 } accept comment "Tailscale allowed TCP ports"
          udp dport ${toString config.services.tailscale.port} accept comment "Tailscale UDP port"
        }

        chain forward {
          type filter hook forward priority filter; policy accept;
          iifname "tailscale0" accept comment "Allow Tailscale to WAN"
          oifname "tailscale0" accept comment "Allow WAN back to Tailscale"
          ct state established,related accept
        }
      }

      table ip tailscale-nat {
          chain postrouting {
              type nat hook postrouting priority srcnat; policy accept;
              iifname "tailscale0" oifname { "eth0", "wlan0" } masquerade comment "Masquerade Tailscale Exit Node traffic"
          }
      }
    '';
  };
}
