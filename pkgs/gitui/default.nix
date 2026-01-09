{pkgs, ...}:
pkgs.symlinkJoin {
  name = "gitui";
  paths = [pkgs.gitui];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/gitui \
        --set XDG_CONFIG_HOME $out/config

    mkdir -p $out/config/git
    cp ${./config.toml} $out/config/git/config

    mkdir -p $out/config/gitui
    cp ${./theme.ron} $out/config/gitui/theme.ron
    cp ${./key_bindings.ron} $out/config/gitui/key_bindings.ron
  '';
}
