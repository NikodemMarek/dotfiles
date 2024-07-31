{pkgs, ...}: {
  home.packages = [
    pkgs.kanshi
  ];

  services.kanshi = {
    enable = true;
    systemdTarget = "graphical-session.target";
    profiles = {
      standalone = {
        outputs = [
          {
            criteria = "eDP-1";
            mode = "1920x1080@60";
            position = "0,0";
          }
        ];
      };
      docked = {
        outputs = [
          {
            criteria = "eDP-1";
            mode = "1920x1080@60";
            position = "0,0";
          }
          {
            criteria = "DP-3";
            mode = "1920x1080@60";
            position = "0,-1080";
          }
          {
            criteria = "DP-4";
            mode = "1920x1080@60";
            position = "1920,-1260";
            transform = "270";
          }
        ];
      };
      docked_after_reconnect = {
        outputs = [
          {
            criteria = "eDP-1";
            mode = "1920x1080@60";
            position = "0,0";
          }
          {
            criteria = "DP-5";
            mode = "1920x1080@60";
            position = "0,-1080";
          }
          {
            criteria = "DP-6";
            mode = "1920x1080@60";
            position = "1920,-1260";
            transform = "270";
          }
        ];
      };
    };
  };
}
