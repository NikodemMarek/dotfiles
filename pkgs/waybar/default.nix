{pkgs, ...}:
pkgs.symlinkJoin {
  name = "waybar";
  paths = [pkgs.waybar];
  buildInputs = [pkgs.makeWrapper];
  postBuild = let
    extraPkgs = [pkgs.tailscale];
  in ''
    wrapProgram $out/bin/waybar \
        --suffix PATH : ${pkgs.lib.strings.makeBinPath extraPkgs} \
        --add-flags "--config $out/config/waybar/config.json" \
        --add-flags "--style $out/config/waybar/style.css"

    mkdir -p $out/config/waybar
    cp ${./config.json} $out/config/waybar/config.json
    cp ${./colors.css} $out/config/waybar/colors.css
    cp ${./style.css} $out/config/waybar/style.css
  '';
}
