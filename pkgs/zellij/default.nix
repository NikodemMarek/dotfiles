{pkgs, ...}:
pkgs.symlinkJoin {
  name = "zellij";
  paths = [pkgs.zellij];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/zellij \
        --add-flags "--config ${./config.kdl}"
  '';
}
