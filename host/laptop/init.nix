{pkgs, ...}: {
  programs = {
    hyprland.enable = true;
    fish.enable = true;
  };

  security.rtkit.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --cmd ${pkgs.hyprland}/bin/Hyprland -r -t";
      };
    };
  };
}
