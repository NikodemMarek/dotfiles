{pkgs, ...}:
pkgs.symlinkJoin {
  name = "jujutsu";
  paths = [pkgs.jujutsu];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/jj \
        --add-flags "--config-file $out/.config/jujutsu/config.toml"

    mkdir -p $out/.config/jujutsu
    cp ${./config.toml} $out/.config/jujutsu/config.toml
  '';
}
