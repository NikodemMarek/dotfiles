{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.event-router;
  eventRouter = lib.getExe pkgs.event-router;
in {
  options.services.event-router.enable = lib.mkEnableOption "the event router and the knowledge curator timers";

  config = lib.mkIf cfg.enable {
    systemd.user.services = {
      event-router = {
        description = "Dispatch events to handlers";
        wantedBy = ["default.target"];
        after = ["graphical-session.target"];
        serviceConfig = {
          ExecStart = "${eventRouter} serve";
          Restart = "on-failure";
          RestartSec = 10;
          # handlers may start long-lived processes (e.g. a zellij session); a
          # restart must not take them down
          KillMode = "process";
        };
      };

      knowledge-curate = {
        description = "Ask the knowledge curator to process pending submissions";
        wants = ["event-router.service"];
        after = ["event-router.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${eventRouter} emit knowledge.curate";
        };
        startAt = "*-*-* 00/6:15:00";
      };

      knowledge-curate-weekly = {
        description = "Ask the knowledge curator for its weekly pass";
        wants = ["event-router.service"];
        after = ["event-router.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${eventRouter} emit knowledge.curate.weekly";
        };
        startAt = "Sun *-*-* 04:00:00";
      };
    };

    systemd.user.timers = {
      knowledge-curate.timerConfig = {
        Persistent = true;
        RandomizedDelaySec = "10min";
      };
      knowledge-curate-weekly.timerConfig.Persistent = true;
    };
  };
}
