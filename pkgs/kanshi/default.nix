{
  pkgs,
  kanshi,
  ...
}:
pkgs.symlinkJoin {
  name = "kanshi";
  paths = [kanshi];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/kanshi \
        --add-flags "--config $out/config/kanshi/config"

    mkdir -p $out/config/kanshi
    cp ${./config} $out/config/kanshi/config
  '';
}
