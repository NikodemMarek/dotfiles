{pkgs, ...}:
pkgs.symlinkJoin {
  name = "hyprlauncher";
  paths = [pkgs.hyprlauncher];
  buildInputs = [pkgs.makeWrapper];
  postBuild = let
    extraPkgs = [pkgs.uwsm];
  in ''
    wrapProgram $out/bin/hyprlauncher \
        --suffix PATH : ${pkgs.lib.strings.makeBinPath extraPkgs} \
        --set XDG_CONFIG_HOME $out/config

    mkdir -p $out/config/hypr
    cp ${./config.conf} $out/config/hypr/hyprlauncher.conf
    cp ${../hyprlock/colors.conf} $out/config/hypr/colors.conf
  '';
}
