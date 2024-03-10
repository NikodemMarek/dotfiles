{
  pkgs,
  lib,
  username,
  ...
}: {
  imports = [
    ./wired-notify.nix
  ];

  systemd.user.services."battery-notifier" = {
    Unit = {
      Description = "Low Battery Notification Service";
    };
    Install = {
      WantedBy = ["multi-user.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.writeShellScript "battery-notifier" ''
        #!${pkgs.stdenv.shell}
        # FIXME: This is the dirtiest solution ever, maybe there is PATH variable in home manager?
        PATH=$PATH:/home/${username}/.nix-profile/bin:/nix/profile/bin:/home/${username}/.local/state/nix/profile/bin:/etc/profiles/per-user/${username}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin

        while true; do
            BAT=$(cat /sys/class/power_supply/BAT1/capacity)
            if [[ $BAT -le 10 ]]; then
              notify-send "Battery low ($BAT%)"
            elif [[ $BAT -ge 100 ]]; then
              notify-send "Battery full"
            fi
            sleep 60
        done
      ''}";
    };
  };
}
