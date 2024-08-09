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
            criteria = "DP-3";
            mode = "2560x1440";
            position = "0,0";
          }
          {
            criteria = "HDMI-A-1";
            mode = "1920x1080";
            position = "2560,-240";
            transform = "270";
          }
        ];
      };
    };
  };
}
