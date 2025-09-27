{
  networking = {
    firewall.allowedUDPPorts = [53];
    extraHosts = ''
      192.168.18.95   jellyfin.net
      192.168.18.95   jellyseerr.net

      192.168.18.95   radarr.net
      192.168.18.95   sonarr.net
      192.168.18.95   lidarr.net
      192.168.18.95   readarr.net
      192.168.18.95   prowlarr.net
      192.168.18.95   torrent.net

      192.168.18.95   traefik.net
    '';
  };

  services = {
    resolved.enable = false;
    dnsmasq = {
      enable = true;
      settings.server = ["9.9.9.9" "1.1.1.1"];
    };
  };
}
