{
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [
    wl-clipboard
    (config.lib.nixGL.wrap wl-mirror)
    grim
    slurp
    pulseaudio
    (config.lib.nixGL.wrap wdisplays)
  ];

  programs.hyprlock = {
    enable = true;
    package = pkgs.wrapped.hyprlock;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = config.lib.nixGL.wrap pkgs.wrapped.hyprland;
    portalPackage = config.lib.nixGL.wrap pkgs.wrapped.hyprland;
    xwayland.enable = true;
  };
}
