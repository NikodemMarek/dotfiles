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
          name = "standalone";
          outputs = [
            {
              criteria = "eDP-1";
              mode = "1920x1080";
              position = "0,0";
            }
          ];
        };
      }
      {
        profile = {
          name = "dual-monitor";
          outputs = [
            {
              criteria = "eDP-1";
              mode = "1920x1080";
              position = "640,1920";
            }
            {
              criteria = "DP-4";
              mode = "2560x1440";
              position = "0,0";
            }
            {
              criteria = "DP-3";
              mode = "2560x1440";
              position = "2560,0";
              transform = "270";
            }
          ];
        };
      }
      {
        profile = {
          name = "dual-monitor-2";
          outputs = [
            {
              criteria = "eDP-1";
              mode = "1920x1080";
              position = "640,1440";
            }
            {
              criteria = "DP-6";
              mode = "2560x1440";
              position = "0,0";
            }
            {
              criteria = "DP-5";
              mode = "2560x1440";
              position = "2560,0";
              transform = "270";
            }
          ];
        };
      }
    ];
  };
}
