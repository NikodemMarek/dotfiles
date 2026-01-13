{
  networking.firewall.interfaces."br0-virtint".allowedTCPPorts = [2049];

  services.nfs.server = {
    enable = true;
    exports = ''
      /persist/apps/navidrome  192.168.74.0/24(rw,sync,fsid=1,insecure,no_root_squash,no_subtree_check)
      /persist/apps/jellyfin   192.168.74.0/24(rw,sync,fsid=2,insecure,no_root_squash,no_subtree_check)
      /persist/apps/seerr      192.168.74.0/24(rw,sync,fsid=3,insecure,no_root_squash,no_subtree_check)

      /mnt/data/music          192.168.74.0/24(ro,sync,fsid=10,insecure,no_root_squash,no_subtree_check)
      /mnt/data/movies         192.168.74.0/24(ro,sync,fsid=11,insecure,no_root_squash,no_subtree_check)
      /mnt/data/shows          192.168.74.0/24(ro,sync,fsid=12,insecure,no_root_squash,no_subtree_check)
      /mnt/data/books          192.168.74.0/24(ro,sync,fsid=13,insecure,no_root_squash,no_subtree_check)
    '';
  };
}
