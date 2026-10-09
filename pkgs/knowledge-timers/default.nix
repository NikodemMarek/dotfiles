{
  runCommand,
  event-router,
}:

# systemd user units that ask the knowledge curator to run, by emitting events.
# A separate package: event-router depends on the handlers, so the handler
# can't reference event-router. Absolute ExecStart: a new router changes the
# units, so sd-switch picks it up.
runCommand "knowledge-timers" { } ''
  mkdir -p "$out/share/systemd/user"
  cd "$out/share/systemd/user"

  cat > knowledge-curate.service <<EOF
  [Unit]
  Description=Ask the knowledge curator to process pending submissions
  Wants=event-router.service
  After=event-router.service

  [Service]
  Type=oneshot
  ExecStart=${event-router}/bin/event-router emit knowledge.curate
  EOF

  cat > knowledge-curate.timer <<EOF
  [Unit]
  Description=Process pending knowledge submissions every 6 hours

  [Timer]
  OnCalendar=*-*-* 00/6:15:00
  Persistent=true
  RandomizedDelaySec=10min

  [Install]
  WantedBy=timers.target
  EOF

  cat > knowledge-curate-weekly.service <<EOF
  [Unit]
  Description=Ask the knowledge curator for its weekly pass
  Wants=event-router.service
  After=event-router.service

  [Service]
  Type=oneshot
  ExecStart=${event-router}/bin/event-router emit knowledge.curate.weekly
  EOF

  cat > knowledge-curate-weekly.timer <<EOF
  [Unit]
  Description=Weekly knowledge curator pass

  [Timer]
  OnCalendar=Sun *-*-* 04:00:00
  Persistent=true

  [Install]
  WantedBy=timers.target
  EOF
''
