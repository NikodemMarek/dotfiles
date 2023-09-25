{ config, pkgs, lib, resolution, ... }:
let
    windows = [
        # x y width height
        [ "powermenu" 12 0 4 2 ]
        [ "system" 0 2 4 3 ]
        [ "time" 4 2 8 5 ]
        [ "music" 0 5 4 2 ]
    ];
in {
  extraPkgs = [
    "eww-wayland"
    "playerctl"
  ];

  module = { ... }:
  let
    grid = { width = resolution.width / 16; height = resolution.height / 9; };
    border = 10;

    str = s: builtins.toString (s);
  in {
    xdg.configFile.eww = {
      source = ./eww;
      recursive = true;
    };

    xdg.configFile."eww/eww.yuck".text = ''
      (include "./dashboard.yuck")

      ; windows
      ${builtins.concatStringsSep "\n" ( builtins.map ( win: ''
          (defwindow ${builtins.elemAt win 0} :stacking "bottom" :focusable true :exclusive false :monitor 0
              :geometry (geometry :x ${str (grid.width * builtins.elemAt win 1 + border)} :y ${str (grid.height * builtins.elemAt win 2 + border)} :width ${str (grid.width * builtins.elemAt win 3 - border * 2)} :height ${str (grid.height * builtins.elemAt win 4 - border * 2)})
                  (${builtins.elemAt win 0}))
      '') windows )}
    '';
  };

  autorun = ''
    eww daemon

    ${lib.concatStrings ( builtins.map ( win: ''
      eww open ${builtins.elemAt win 0}
    '') windows )}
  '';
}
