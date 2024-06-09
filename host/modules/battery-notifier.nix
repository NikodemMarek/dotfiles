{
  lib,
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
  };

  config = lib.mkIf cfg.enable {
    systemd.timers.battery-notifier = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "0m";
        OnCalendar = "*:0/1";
        Unit = "battery-notifier.service";
      };
    };

    systemd.services.battery-notifier = {
      script = ''
        BAT=$(cat ${cfg.capacityPath})
        STATUS=$(cat ${cfg.statusPath})

        echo $BAT $STATUS

        if [[ $BAT -le 10 && $STATUS == "Discharging" ]]; then
          notify-send "Battery low ($BAT%)"
        elif [[ $BAT -ge 100 && $STATUS == "Charging" ]]; then
          notify-send "Battery full"
        fi
      '';
      serviceConfig = {
        Type = "forking";
        User = "root";
      };
    };
  };
}
