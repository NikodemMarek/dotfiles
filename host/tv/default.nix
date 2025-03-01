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
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keyFiles = [
        ../laptop/user_nikodem_ssh_id_ed25519.pub
        ../desktop/user_nikodem_ssh_id_ed25519.pub
      ];
    };
  };

  programs.firefox = {
    enable = true;
    preferences = {
      "browser.shell.checkDefaultBrowser" = false;
      "browser.shell.defaultBrowserCheckCount" = 1;
    };
  };

  services.cage = {
    enable = true;
    program = lib.getExe pkgs.firefox;
    user = "tv";
    extraArguments = ["-m" "last" "-s"];
  };
  systemd.services."cage-tty1" = {
    after = [
      "network-online.target"
      "systemd-resolved.service"
    ];
    postStop = "/usr/bin/env poweroff";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
