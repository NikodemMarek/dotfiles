{
  pkgs,
  hyprlock,
  wallpaper,
  ...
}:
pkgs.symlinkJoin {
  name = "hyprlock";
  paths = [hyprlock];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/hyprlock \
        --set CONF $out \
        --add-flags "--config ${./config.conf}"

    cp ${./colors.conf} $out/colors.conf
    cp ${wallpaper} $out/background.png
  '';
}
