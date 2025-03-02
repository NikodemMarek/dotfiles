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

  services.pipewire = {
    enable = true;
    audio.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    systemWide = true;
    wireplumber = {
      enable = true;
      extraConfig."50-default-sink" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              {
                "node.name" = "alsa_output.pci-0000_00_03.0.hdmi-stereo";
              }
            ];
            actions = {
              "update-props" = {
                "node.default" = true;
              };
            };
          }
        ];
      };
    };
  };

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
    program = "${lib.getExe pkgs.firefox} --new-instance --no-remote about:blank";
    user = "root";
    extraArguments = ["-m" "last"];
  };
  systemd.services."cage-tty1" = {
    after = [
      "network-online.target"
      "systemd-resolved.service"
    ];
    postStop = "/usr/bin/env poweroff";
  };
  systemd.services."default-sink" = {
    after = [
      "pipewire.service"
      "wireplumber.service"
    ];
    requires = ["pipewire.service" "wireplumber.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "1m";
    };
    script = lib.getExe (pkgs.writeShellScriptBin "default-sink" ''
      echo "Waiting for PipeWire and WirePlumber to initialize..."
      sleep 20
      echo "Setting default sink to ID 48..."
      ${pkgs.wireplumber}/bin/wpctl set-default 48
      if [ $? -eq 0 ]; then
        echo "Default sink set successfully!"
      else
        echo "Failed to set default sink."
        exit 1
      fi
    '');
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
