{ config, pkgs, lib, settings, ... }:
let
  windows = [
    # widget x y width height
    [ "powermenu" 12 0 4 2 ]
    [ "system" 0 2 4 3 ]
    [ "time" 4 2 8 5 ]
    [ "music" 0 5 4 2 ]
    [ "shortcuts" 0 0 4 2 ]
    [ "volume" 4 0 4 2 ]
  ];

  grid = { width = settings.resolution.width / 16; height = settings.resolution.height / 9; };
  border = 10;

  str = builtins.toString;
in
{
  home.packages = with pkgs; [
    eww-wayland
    playerctl
  ];

  xdg.configFile.eww = {
    source = ./eww;
    recursive = true;
  };

  xdg.configFile."eww/device_specific.yuck".text = ''
    ; system
    (defwidget system [] 
        (box :class "system dashboard_window" :vexpand false :hexpand false 
            (box :orientation "h" :spacing 35 :halign "center" :valign "center" :space-evenly false :vexpand false :hexpand false 
                (box :class "system_cpu_bar" :orientation "v" :spacing 20 :space-evenly false :vexpand false :hexpand false
                    (progress :value { EWW_CPU.avg } :orientation "v" :flipped true)
                    (label :class "system_iconcpu" :text ""))
                (box :class "system_mem_bar" :orientation "v" :spacing 20 :space-evenly false :vexpand false :hexpand false 
                    (progress :value { EWW_RAM.used_mem_perc } :orientation "v" :flipped true)
                    (label :class "system_iconmem" :text ""))
                (box :class "system_drive_bar" :orientation "v" :spacing 20 :space-evenly false :vexpand false :hexpand false 
                    (progress :value { EWW_DISK["/home"].used_perc } :orientation "v" :flipped true)
                    (label :class "system_icondrive" :text "󰋊"))
                ${if settings.device == "laptop" then ''
                  (box :class "system_bat_bar" :orientation "v" :spacing 20 :space-evenly false :vexpand false :hexpand false 
                      (progress :value { EWW_BATTERY.total_avg } :orientation "v" :flipped true)
                      (label :class "system_iconbat" :text "󰁹"))
                '' else ""})))

    ; shortcuts
    (defwidget shortcuts [] 
        (box :class "shortcuts dashboard_window" :orientation "v" :space-evenly false
            ${builtins.concatStringsSep "\n" ( builtins.map ( row: ''
                (box :vexpand true :hexpand true
                    ${builtins.concatStringsSep "\n" ( builtins.map ( item: ''
                        (button :class "shortcuts_button" :onclick "${builtins.elemAt item 0} &" "${builtins.elemAt item 1}")
                    '' ) row )})
            '' ) settings.eww.shortcuts )})
  '';

  xdg.configFile."eww/eww.yuck".text = ''
    (include "./dashboard.yuck")
    (include "./device_specific.yuck")

    ; windows
    ${builtins.concatStringsSep "\n" ( builtins.map ( win: ''
        (defwindow ${builtins.elemAt win 0} :stacking "bottom" :focusable true :exclusive false :monitor 0
            :geometry (geometry :x ${str (grid.width * builtins.elemAt win 1 + border)} :y ${str (grid.height * builtins.elemAt win 2 + border)} :width ${str (grid.width * builtins.elemAt win 3 - border * 2)} :height ${str (grid.height * builtins.elemAt win 4 - border * 2)})
                (${builtins.elemAt win 0}))
    '') windows )}
  '';
}
