{
  pkgs,
  lib,
  ...
}: {
  home.packages = [
    pkgs.kanshi
  ];

  services.kanshi = {
    enable = true;
    systemdTarget = "graphical-session.target";
    settings = let
      mkMove = script: ''${lib.getExe
          (pkgs.writeShellScriptBin
            "move-workspaces"
            script)}'';
    in [
      {
        profile = {
          name = "standalone";
          exec = [
            (mkMove
              ''
                hyprctl dispatch moveworkspacetomonitor "1 eDP-1"
                hyprctl dispatch moveworkspacetomonitor "2 eDP-1"
              '')
          ];
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
          name = "docked";

          exec = [
            (mkMove
              ''
                hyprctl dispatch moveworkspacetomonitor "1 DP-4"
                hyprctl dispatch moveworkspacetomonitor "2 DP-3"
              '')
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
      }
      {
        profile = {
          name = "docked_after_reconnect";
          exec = [
            (mkMove
              ''
                hyprctl dispatch moveworkspacetomonitor "1 DP-6"
                hyprctl dispatch moveworkspacetomonitor "2 DP-5"
              '')
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
      }
      {
        profile = {
          name = "home";
          exec = [
            (mkMove
              ''
                hyprctl dispatch moveworkspacetomonitor "1 eDP-1"
                hyprctl dispatch moveworkspacetomonitor "2 HDMI-A-1"
              '')
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
      }
      {
        profile = {
          name = "home_small";
          exec = [
            (mkMove
              ''
                hyprctl dispatch moveworkspacetomonitor "1 eDP-1"
                hyprctl dispatch moveworkspacetomonitor "2 HDMI-A-1"
              '')
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
      }
      {
        profile = {
          name = "tv";
          exec = [
            (mkMove
              ''
                hyprctl dispatch moveworkspacetomonitor "1 eDP-1"
                hyprctl dispatch moveworkspacetomonitor "2 eDP-1"
              '')
          ];
          outputs = [
            {
              criteria = "eDP-1";
              mode = "1920x1080";
              position = "0,0";
            }
            {
              criteria = "DP-2";
              mode = "1920x1080";
              position = "0,0";
            }
          ];
        };
      }
    ];
  };
}
