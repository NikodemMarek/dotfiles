{config, ...}: {
  systemd.network = {
    enable = true;
    networks = {
      "10-wired-default" = {
        matchConfig.Name = "en*";
        networkConfig.DHCP = "yes";
      };
    };
  };

  networking = {
    wireless = {
      userControlled.enable = true;
      networks = let
        # FIXME: Temporary solution that only works if secrets are already present on the host.
        readIfExists = path:
          if builtins.pathExists path
          then builtins.readFile path
          else null;
      in {
        "Meshki56".psk = readIfExists config.sops.secrets."networks/Meshki56/psk";
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
