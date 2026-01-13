{pkgs, ...}:
pkgs.symlinkJoin {
  name = "rofi";
  paths = [pkgs.rofi];
  buildInputs = [pkgs.makeWrapper];
  postBuild = let
    extraPkgs = [pkgs.uwsm];
  in ''
    wrapProgram $out/bin/rofi \
        --suffix PATH : ${pkgs.lib.strings.makeBinPath extraPkgs} \
        --add-flags "-config $out/config/rofi/config.rasi"

    mkdir -p $out/config/rofi
    cp ${./config.rasi} $out/config/rofi/config.rasi
    cp ${./colors.rasi} $out/config/rofi/colors.rasi
  '';
}
