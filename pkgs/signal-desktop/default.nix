{pkgs, ...}:
pkgs.symlinkJoin {
  name = "signal-desktop";
  paths = [pkgs.signal-desktop];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/signal-desktop \
        --suffix XDG_CONFIG_HOME "" "$HOME/.local/share"
  '';
}
