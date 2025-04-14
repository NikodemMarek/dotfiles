{pkgs, ...}: {
  home.packages = [
    pkgs.kanshi
  ];

  services.kanshi = {
    enable = true;
    systemdTarget = "graphical-session.target";
    settings = [
      {
        profile = {
          name = "main";
          outputs = [
            {
              criteria = "DP-3";
              mode = "2560x1440";
              position = "0,0";
            }
            {
              criteria = "HDMI-A-1";
              mode = "1920x1080";
              position = "-1080,-240";
              transform = "90";
            }
          ];
        };
      }
    ];
  };
}
