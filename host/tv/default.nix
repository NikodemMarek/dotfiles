{
  pkgs,
  lib,
  ...
}: {
  imports = [
    (import ../features/disko/hybrid-tmpfs-on-root.nix {
      device = "/dev/sda";
    })

    ../features/battery-saver.nix
    ../features/bluetooth.nix
  ];

  networking.hostName = "tv";

  users.users = {
    tv = {
      isNormalUser = true;
      password = "tv";
      openssh.authorizedKeys.keyFiles = [
        ../laptop/user_nikodem_ssh_id_ed25519.pub
        ../desktop/user_nikodem_ssh_id_ed25519.pub
      ];
    };
  };

  services.cage = {
    enable = true;
    program = lib.getExe pkgs.firefox;
    user = "tv";
  };
  systemd.services."cage-tty1".after = [
    "network-online.target"
    "systemd-resolved.service"
  ];
}
