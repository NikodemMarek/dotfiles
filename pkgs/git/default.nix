{pkgs, ...}:
pkgs.symlinkJoin {
  name = "git";
  paths = [pkgs.git];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/git \
        --set XDG_CONFIG_HOME $out/.config

    mkdir -p $out/.config/git
    cp ${./config.toml} $out/.config/git/config
  '';
}
