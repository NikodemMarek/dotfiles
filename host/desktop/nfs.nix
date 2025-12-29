{
  networking.firewall.interfaces."br0".allowedTCPPorts = [2049];

  services.nfs.server = {
    enable = true;
    exports = ''
      /persist/apps/navidrome  192.168.74.0/24(rw,sync,fsid=1,insecure,no_root_squash,no_subtree_check)
    '';
  };
}
