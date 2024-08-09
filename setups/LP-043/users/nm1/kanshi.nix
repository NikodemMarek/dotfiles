{pkgs, ...}: {
  home.packages = [
    pkgs.kanshi
  ];

  services.kanshi = {
    enable = true;
    systemdTarget = "graphical-session.target";
    profiles = {
      standalone = {
        exec = [
          ''
            ${
              pkgs.writeShellScriptBin
              "move-workspaces-standalone"
              ''
                hyprctl dispatch moveworkspacetomonitor "1 eDP-1"
                hyprctl dispatch moveworkspacetomonitor "2 eDP-1"
                hyprctl dispatch moveworkspacetomonitor "3 eDP-1"
              ''
            }/bin/move-workspaces-standalone
          ''
        ];
        outputs = [
          {
            criteria = "eDP-1";
            mode = "1920x1080";
            position = "0,0";
          }
        ];
      };
      docked = {
        exec = [
          ''
            ${
              pkgs.writeShellScriptBin
              "move-workspaces-docked"
              ''
                hyprctl dispatch moveworkspacetomonitor "1 DP-4"
                hyprctl dispatch moveworkspacetomonitor "2 DP-4"
                hyprctl dispatch moveworkspacetomonitor "3 DP-3"
              ''
            }/bin/move-workspaces-docked
          ''
        ];
        outputs = [
          {
            criteria = "eDP-1";
            mode = "1920x1080";
            position = "0,0";
          }
          {
            criteria = "DP-3";
            mode = "1920x1080";
            position = "0,-1080";
          }
          {
            criteria = "DP-4";
            mode = "1920x1080";
            position = "1920,-1260";
            transform = "270";
          }
        ];
      };
      docked_after_reconnect = {
        exec = [
          ''
            ${
              pkgs.writeShellScriptBin
              "move-workspaces-docked_after_reconnect"
              ''
                hyprctl dispatch moveworkspacetomonitor "1 DP-6"
                hyprctl dispatch moveworkspacetomonitor "2 DP-6"
                hyprctl dispatch moveworkspacetomonitor "3 DP-5"
              ''
            }/bin/move-workspaces-docked_after_reconnect
          ''
        ];
        outputs = [
          {
            criteria = "eDP-1";
            mode = "1920x1080";
            position = "0,0";
          }
          {
            criteria = "DP-5";
            mode = "1920x1080";
            position = "0,-1080";
          }
          {
            criteria = "DP-6";
            mode = "1920x1080";
            position = "1920,-1260";
            transform = "270";
          }
        ];
      };
      home = {
        exec = [
          ''
            ${
              pkgs.writeShellScriptBin
              "move-workspaces-home"
              ''
                hyprctl dispatch moveworkspacetomonitor "1 eDP-1"
                hyprctl dispatch moveworkspacetomonitor "2 eDP-1"
                hyprctl dispatch moveworkspacetomonitor "3 HDMI-A-1"
              ''
            }/bin/move-workspaces-home
          ''
        ];
        outputs = [
          {
            criteria = "eDP-1";
            mode = "1920x1080";
            position = "0,0";
          }
          {
            criteria = "LG HDMI-A-1";
            mode = "2560x1440";
            position = "-2560,-1180";
          }
        ];
      };
      home_small = {
        exec = [
          ''
            ${
              pkgs.writeShellScriptBin
              "move-workspaces-home"
              ''
                hyprctl dispatch moveworkspacetomonitor "1 eDP-1"
                hyprctl dispatch moveworkspacetomonitor "2 eDP-1"
                hyprctl dispatch moveworkspacetomonitor "3 HDMI-A-1"
              ''
            }/bin/move-workspaces-home
          ''
        ];
        outputs = [
          {
            criteria = "eDP-1";
            mode = "1920x1080";
            position = "0,0";
          }

          {
            criteria = "Acer Technologies QG241Y TGHEE0018511";
            mode = "1920x1080";
            position = "1920,-1260";
            transform = "270";
          }
        ];
      };
    };
  };
}
