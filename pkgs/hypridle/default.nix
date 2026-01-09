{pkgs, ...}:
pkgs.symlinkJoin {
  name = "hypridle";
  paths = [pkgs.hypridle];
  buildInputs = [pkgs.makeWrapper];
  postBuild = let
    extraPkgs = [pkgs.wrapped.hyprlock pkgs.brightnessctl];
  in ''
    wrapProgram $out/bin/hypridle \
        --suffix PATH : ${pkgs.lib.strings.makeBinPath extraPkgs} \
        --set XDG_CONFIG_HOME $out/.config \
        --add-flags "--config $out/bin/config.conf"

    cp ${./config.conf} $out/bin/config.conf

    # TODO: remove when hypridle fixes bug with --config
    mkdir -p $out/.config/hypr
    touch $out/.config/hypr/hypridle.conf
  '';
}
