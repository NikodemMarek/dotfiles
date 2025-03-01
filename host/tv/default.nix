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

  environment.etc."wireplumber/main.lua.d/50-alsa-config.lua".text = ''
    -- Set HDMI as the default audio device
    rule = {
      matches = {
        {
          { "device.name", "equals", "alsa_output.pci-0000_00_03.0.hdmi-stereo" },
        },
      },
      apply_properties = {
        ["api.alsa.headroom"] = 1024,
        ["api.alsa.period-size"] = 1024,
        ["api.alsa.period-num"] = 2,
        ["device.profile"] = "hdmi-stereo", -- Use the HDMI profile
      },
    }
    table.insert(alsa_monitor.rules, rule)
  '';

  services.cage = {
    enable = true;
    program = "${lib.getExe pkgs.firefox} --new-instance --no-remote about:blank";
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
