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

  users.users.root = {
    password = "tv";
    openssh.authorizedKeys.keyFiles = [
      ../laptop/user_nikodem_ssh_id_ed25519.pub
      ../desktop/user_nikodem_ssh_id_ed25519.pub
    ];
  };

  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

  programs.firefox = {
    enable = true;
    preferences = {
      "browser.shell.checkDefaultBrowser" = false;
      "browser.shell.defaultBrowserCheckCount" = 1;
      "trailhead.firstrun.didSeeAboutWelcome" = true;
    };
  };

  services.cage = {
    enable = true;
    program = lib.getExe (pkgs.writeShellScriptBin "run" ''
      ${lib.getExe pkgs.firefox} --new-instance --no-remote about:blank
    '');
    user = "root";
    extraArguments = ["-m" "last"];
  };
  systemd.services."cage-tty1" = {
    after = [
      "network-online.target"
      "systemd-resolved.service"
      "wireplumber.service"
      "pipewire.service"
      "graphical.target"
    ];
    postStart = "${pkgs.wireplumber}/bin/wpctl set-default 50";
    postStop = "/usr/bin/env poweroff";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
