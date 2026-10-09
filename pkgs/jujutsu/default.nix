{
  pkgs,
  jujutsu,
  jj-upload,
  ...
}:
pkgs.symlinkJoin {
  name = "jujutsu";
  paths = [jujutsu];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    # JJ_CONFIG makes this the user config (~/.config/jj/config.toml is not
    # read) and, unlike --config-file, lets it define aliases.
    wrapProgram $out/bin/jj --set JJ_CONFIG $out/.config/jujutsu/config.toml

    mkdir -p $out/.config/jujutsu
    substitute ${./config.toml} $out/.config/jujutsu/config.toml \
      --subst-var-by jjUpload ${jj-upload}/bin/jj-upload
  '';
}
