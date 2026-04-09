{pkgs, ...}:
pkgs.symlinkJoin {
  name = "claude";
  paths = [pkgs.claude-code];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    # Force claude to not create config in home directory
    wrapProgram $out/bin/claude \
        --suffix HOME "" "/.local/share/claude"
  '';
}
