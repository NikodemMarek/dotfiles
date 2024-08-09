{pkgs, ...}: {
  home.packages = [
    pkgs.kanshi
  ];

  services.kanshi = {
    enable = true;
    systemdTarget = "graphical-session.target";
    profiles = {
      main = {
        outputs = [
          {
            criteria = "eDP-1";
            mode = "1920x1080";
            position = "0,0";
          }
        ];
      };
    };
  };
}
