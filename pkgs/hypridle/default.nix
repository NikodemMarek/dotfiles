{pkgs, ...}:
pkgs.symlinkJoin {
  name = "hypridle";
  paths = [pkgs.hypridle];
  buildInputs = [pkgs.makeWrapper];
  postBuild = ''
    # TODO: remove when hypridle fixes bug with --config
    mkdir -p $out/.config/hypr
    touch $out/.config/hypr/hypridle.conf

    wrapProgram $out/bin/hypridle \
        --set XDG_CONFIG_HOME $out/.config \
        --set PATH "${pkgs.hyprlock}/bin:${pkgs.brightnessctl}/bin:\$PATH" \
        --add-flags "--config ${./config.conf}"
  '';
}
