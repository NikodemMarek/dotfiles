{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    hyprpaper
  ];

  xdg.configFile."hypr/hyprpaper.conf".text = ''
    ipc = off

    preload = ${./../../../assets/background.png}
    wallpaper = , ${./../../../assets/background.png}
  '';
}
