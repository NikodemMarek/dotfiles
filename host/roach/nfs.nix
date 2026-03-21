# to create new export, create a brtfs volume: `btrfs subvolume create <directory>`
{


  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/data/music          100.0.0.0/8(rw,sync,fsid=1,insecure,no_root_squash,no_subtree_check)
      /mnt/data/movies         100.0.0.0/8(rw,sync,fsid=2,insecure,no_root_squash,no_subtree_check)
      /mnt/data/shows          100.0.0.0/8(rw,sync,fsid=3,insecure,no_root_squash,no_subtree_check)
      /mnt/data/books          100.0.0.0/8(rw,sync,fsid=4,insecure,no_root_squash,no_subtree_check)
      /mnt/data/photos         100.0.0.0/8(rw,sync,fsid=5,insecure,no_root_squash,no_subtree_check)
      /mnt/data/files          100.0.0.0/8(rw,sync,fsid=6,insecure,no_root_squash,no_subtree_check)

      /persist/apps/longhorn   100.0.0.0/8(rw,sync,fsid=20,insecure,no_root_squash,no_subtree_check)
    '';
  };
}
