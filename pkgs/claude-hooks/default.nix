{
  lib,
  symlinkJoin,
  writeShellApplication,
  jq,
  coreutils,
  git,
  util-linux,
  findutils,
  gnugrep,
  gnused,
  python3,
  jujutsu,
  stdenvNoCC,
  makeWrapper,
}:

let
  shellHook =
    {
      name,
      src,
      runtimeInputs,
      bashOptions ? null,
    }:
    writeShellApplication (
      {
        inherit name runtimeInputs;
        text = builtins.readFile src;
      }
      // lib.optionalAttrs (bashOptions != null) { inherit bashOptions; }
    );

  guardWrites = shellHook {
    name = "claude-guard-writes";
    src = ./guard-writes.sh;
    runtimeInputs = [
      jq
      coreutils
    ];
  };

  verifierGuard = shellHook {
    name = "claude-verifier-guard";
    src = ./verifier-bash-guard.sh;
    runtimeInputs = [
      jq
      coreutils
      gnugrep
      gnused
    ];
  };

  # Deliberately without errexit: a failing git call must never fail the hook.
  architectAutocommit = shellHook {
    name = "claude-architect-autocommit";
    src = ./architect-autocommit.sh;
    runtimeInputs = [
      jq
      coreutils
      git
      util-linux
      findutils
    ];
    bashOptions = [
      "nounset"
      "pipefail"
    ];
  };

  jjWorkspace = stdenvNoCC.mkDerivation {
    pname = "claude-jj-workspace";
    version = "0.1.0";

    dontUnpack = true;
    nativeBuildInputs = [ makeWrapper ];

    installPhase = ''
      runHook preInstall
      install -Dm755 ${./jj-workspace.py} $out/bin/claude-jj-workspace
      substituteInPlace $out/bin/claude-jj-workspace \
        --replace-fail "#!/usr/bin/env python3" "#!${python3}/bin/python3"
      wrapProgram $out/bin/claude-jj-workspace \
        --suffix PATH : ${
          lib.makeBinPath [
            jujutsu
            git
          ]
        }
      runHook postInstall
    '';

    meta.mainProgram = "claude-jj-workspace";
  };
in
symlinkJoin {
  name = "claude-hooks";
  paths = [
    guardWrites
    verifierGuard
    architectAutocommit
    jjWorkspace
  ];

  meta = {
    description = "Claude Code hook commands: write/bash guards, architect memory autocommit, jj workspaces for isolated agents";
    platforms = lib.platforms.unix;
  };
}
