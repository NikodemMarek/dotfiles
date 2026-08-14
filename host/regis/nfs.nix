{
  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/backups        100.0.0.0/8(rw,sync,fsid=1,insecure,no_root_squash,no_subtree_check) 10.42.0.0/16(rw,sync,fsid=1,insecure,no_root_squash,no_subtree_check)
      /mnt/movies         100.0.0.0/8(rw,sync,fsid=2,insecure,no_root_squash,no_subtree_check) 10.42.0.0/16(rw,sync,fsid=2,insecure,no_root_squash,no_subtree_check)
      /mnt/shows          100.0.0.0/8(rw,sync,fsid=3,insecure,no_root_squash,no_subtree_check) 10.42.0.0/16(rw,sync,fsid=3,insecure,no_root_squash,no_subtree_check)
      /mnt/music          100.0.0.0/8(rw,sync,fsid=4,insecure,no_root_squash,no_subtree_check) 10.42.0.0/16(rw,sync,fsid=1,insecure,no_root_squash,no_subtree_check)
      /mnt/books          100.0.0.0/8(rw,sync,fsid=5,insecure,no_root_squash,no_subtree_check) 10.42.0.0/16(rw,sync,fsid=4,insecure,no_root_squash,no_subtree_check)
      /mnt/photos         100.0.0.0/8(rw,sync,fsid=6,insecure,no_root_squash,no_subtree_check) 10.42.0.0/16(rw,sync,fsid=5,insecure,no_root_squash,no_subtree_check)
      /mnt/files          100.0.0.0/8(rw,sync,fsid=7,insecure,no_root_squash,no_subtree_check) 10.42.0.0/16(rw,sync,fsid=6,insecure,no_root_squash,no_subtree_check)
    '';
  };

  systemd.services.nfs-server = {
    after = ["zfs-mount.service" "zfs.target"];
    wants = ["zfs-mount.service"];
    before = ["remote-fs.target"];
  };
}
