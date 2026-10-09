{
  pkgs,
  wallpaper,
  ...
}:
pkgs.symlinkJoin {
  name = "hyprpaper";
  paths = [pkgs.hyprpaper];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/hyprpaper \
        --set XDG_CONFIG_HOME $out/.config

    mkdir -p $out/.config/hypr
    cp ${./config.conf} $out/.config/hypr/hyprpaper.conf
    cp ${wallpaper} $out/.config/hypr/wallpaper.png
  '';
}
