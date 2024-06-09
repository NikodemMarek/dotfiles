{utils, ...}: let
  autorun = utils.autorun {
    name = "battery-notifier";
    script = ''
      while true; do
          BAT=$(cat /sys/class/power_supply/BAT1/capacity)
          STATUS=$(cat /sys/class/power_supply/BAT1/status)

          echo $BAT $STATUS

          if [[ $BAT -le 10 && $STATUS == "Discharging" ]]; then
            notify-send "Battery low ($BAT%)"
          elif [[ $BAT -ge 100 && $STATUS == "Charging" ]]; then
            notify-send "Battery full"
          fi

          sleep 60
      done
    '';
  };
in {
  imports = [
    autorun
    ./wired-notify.nix
  ];
}
