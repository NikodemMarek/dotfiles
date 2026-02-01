{pkgs, ...}:
pkgs.symlinkJoin {
  name = "gemini";
  paths = [pkgs.gemini-cli];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    # Force gemini to not create config in home directory
    wrapProgram $out/bin/gemini \
        --suffix HOME "" "/.local/share"
  '';
}
