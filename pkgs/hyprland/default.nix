{pkgs, ...}:
pkgs.symlinkJoin {
  name = "Hyprland";
  paths = [pkgs.hyprland];
  buildInputs = [pkgs.makeWrapper];
  inherit (pkgs.hyprland) passthru version;
  postBuild = let
    extraPkgs = [
      pkgs.wrapped.hypridle
      pkgs.wrapped.hyprlock
      pkgs.wrapped.zellij
      pkgs.wrapped.hyprlauncher

      pkgs.yazi
      pkgs.zen-browser
      pkgs.alacritty
      pkgs.wl-clipboard
      pkgs.grim
      pkgs.slurp
      pkgs.pulseaudio
      pkgs.wdisplays
      pkgs.wl-mirror
    ];
  in ''
    wrapProgram $out/bin/Hyprland \
        --suffix PATH : ${pkgs.lib.strings.makeBinPath extraPkgs} \
        --add-flags "--config $out/bin/config.conf"

    cp ${./config.conf} $out/bin/config.conf
  '';
}
