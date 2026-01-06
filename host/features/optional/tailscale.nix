{config, ...}: {
  services.tailscale.enable = true;
  networking.firewall = {
    checkReversePath = "loose";
    trustedInterfaces = ["tailscale0"];
    allowedUDPPorts = [config.services.tailscale.port];
  };
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
}
