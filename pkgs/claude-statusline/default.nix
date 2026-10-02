{
  writeShellApplication,
  jq,
  git,
  gnugrep,
  gnused,
  coreutils,
}:

writeShellApplication {
  name = "claude-statusline";
  runtimeInputs = [
    jq
    git
    gnugrep
    gnused
    coreutils
  ];
  # Best-effort output: no errexit/pipefail (e.g. `java -version | head -1`
  # would otherwise abort the line via SIGPIPE). java is optional, taken from PATH.
  bashOptions = [ "nounset" ];
  text = builtins.readFile ./statusline.sh;
  meta.mainProgram = "claude-statusline";
}
