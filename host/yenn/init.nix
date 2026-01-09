{pkgs, ...}: {
  programs = {
    fish.enable = true;
    hyprland = {
      enable = true;
      # withUWSM = true;
      package = pkgs.wrapped.hyprland;
      portalPackage = pkgs.wrapped.hyprland;
      xwayland.enable = true;
    };
    hyprlock = {
      enable = true;
      package = pkgs.wrapped.hyprlock;
    };
  };

  security.rtkit.enable = true;
  services = {
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --cmd Hyprland -r -t";
        };
      };
    };
    hypridle = {
      enable = true;
      package = pkgs.wrapped.hypridle;
    };
  };
}
