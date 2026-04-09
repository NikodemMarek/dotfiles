{pkgs, ...}:
pkgs.symlinkJoin {
  name = "signal-desktop";
  paths = [pkgs.signal-desktop];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    # Force gemini to not create config in home directory
    wrapProgram $out/bin/signal-desktop \
        --suffix XDG_CONFIG_HOME "" "$HOME/.local/share"
  '';
}
