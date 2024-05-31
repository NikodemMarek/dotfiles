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

    preload = ${config.stylix.image}
    wallpaper = , ${config.stylix.image}
  '';
}
