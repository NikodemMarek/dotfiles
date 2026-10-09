{
  pkgs,
  zellij,
  ...
}:
pkgs.symlinkJoin {
  name = "zellij";
  paths = [zellij];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/zellij \
        --add-flags "--config ${./config.kdl}"
  '';
}
