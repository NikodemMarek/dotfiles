{
  pkgs,
  lib,
  utils,
  config,
  ...
}: let
  cfg = config.services.battery-notifier;
in {
  options.services.battery-notifier = {
    enable = lib.mkEnableOption "Battery Notifier";

    capacityPath = lib.mkOption {
      type = lib.types.path;
      default = "/sys/class/power_supply/BAT0/capacity";
      description = "Path to battery capacity file";
    };
    statusPath = lib.mkOption {
      type = lib.types.path;
      default = "/sys/class/power_supply/BAT0/status";
      description = "Path to battery status file";
    };

    lowThreshold = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "Low battery threshold";
    };

    checkInterval = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Interval in minutes to check battery status";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.timers.battery-notifier = {
      Timer = {
        OnBootSec = "0m";
        OnCalendar = "*:0/${utils.str cfg.checkInterval}";
      };
      Install = {
        WantedBy = ["graphical.target"];
      };
    };

    systemd.user.services.battery-notifier = {
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScriptBin "battery-notifier-execstart" ''
          #!${pkgs.stdenv.shell}
          # FIXME: This is the dirtiest solution ever, maybe there is PATH variable in home manager?
          PATH=$PATH:/home/${config.settings.username}/.nix-profile/bin:/nix/profile/bin:/home/${config.settings.username}/.local/state/nix/profile/bin:/etc/profiles/per-user/${config.settings.username}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin

          BAT=$(cat ${cfg.capacityPath})
          STATUS=$(cat ${cfg.statusPath})

          echo $BAT $STATUS

          if [[ $BAT -le ${utils.str cfg.lowThreshold} && $STATUS == "Discharging" ]]; then
            notify-send "Battery low ($BAT%)"
          elif [[ $BAT -ge 100 && $STATUS == "Charging" ]]; then
            notify-send "Battery full"
          fi
        ''}/bin/battery-notifier-execstart";
      };
    };
  };
}
