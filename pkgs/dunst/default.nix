{pkgs, ...}:
pkgs.symlinkJoin {
  name = "dunst";
  paths = [pkgs.dunst];
  buildInputs = [pkgs.makeWrapper];
  postBuild = let
    extraPkgs = [pkgs.libnotify];
  in ''
    wrapProgram $out/bin/dunst \
        --suffix PATH : ${pkgs.lib.strings.makeBinPath extraPkgs} \
        --add-flags "-config $out/config/dunst/dunstrc"

    mkdir -p $out/config/dunst
    cp ${./dunstrc} $out/config/dunst/dunstrc
  '';
}
