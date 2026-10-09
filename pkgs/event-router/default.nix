{
  lib,
  python3Packages,
  linkFarm,
  # event type -> package whose main program handles it. An event goes to its
  # type, else the nearest prefix ("gitlab.note" -> "gitlab"), else `default`.
  handlers ? { },
  port ? 7531,
}:

let
  handlersDir = linkFarm "event-router-handlers" (
    lib.mapAttrsToList (name: drv: {
      inherit name;
      path = lib.getExe drv;
    }) handlers
  );
  url = "http://127.0.0.1:${toString port}";
in
python3Packages.buildPythonApplication {
  pname = "event-router";
  version = "0.1.0";
  pyproject = true;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./pyproject.toml
      ./src
    ];
  };

  build-system = [ python3Packages.setuptools ];
  nativeBuildInputs = [ python3Packages.mypy ];

  # types are part of the build: a mypy --strict error fails it
  preBuild = ''
    MYPY_CACHE_DIR="$TMPDIR/mypy" mypy
  '';

  makeWrapperArgs = [
    "--set"
    "EVENT_ROUTER_HANDLERS"
    "${handlersDir}"
    "--set"
    "EVENT_ROUTER_PORT"
    (toString port)
    "--set"
    "EVENT_ROUTER_URL"
    url
  ];

  # absolute ExecStart: any handler change changes the unit, so sd-switch
  # restarts the service
  postInstall = ''
    mkdir -p "$out/share/systemd/user"
    cat > "$out/share/systemd/user/event-router.service" <<EOF
    [Unit]
    Description=Dispatch events to handlers
    After=graphical-session.target

    [Service]
    ExecStart=$out/bin/event-router serve
    Restart=on-failure
    RestartSec=10
    # handlers may start long-lived processes (e.g. a zellij session); a
    # restart must not take them down
    KillMode=process

    [Install]
    WantedBy=default.target
    EOF
  '';

  passthru = { inherit handlers handlersDir url; };

  meta = {
    description = "Receive events over HTTP and dispatch them to handlers";
    mainProgram = "event-router";
  };
}
