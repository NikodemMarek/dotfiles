{
  config,
  pkgs,
  lib,
  utils,
  ...
}: let
  cfg = config.wm.eww;

  inherit (lib) types;
  inherit (utils) str at;

  primaryMonitor = at config.monitors 0;
  grid = {
    width = primaryMonitor.width / 16;
    height = primaryMonitor.height / 9;
  };

  autorun = utils.autorun {
    name = "eww";
    script = ''
      ${pkgs.eww}/bin/eww daemon

      ${lib.concatStrings (builtins.map (win: ''
          ${pkgs.eww}/bin/eww open ${at win 0}
        '')
        cfg.windows)}
    '';
  };
in {
  imports = [
    autorun
  ];

  options.wm.eww = {
    enable = lib.mkEnableOption "Enable eww";

    border = lib.mkOption {
      type = types.int;
      default = 10;
      description = "The border around the widgets.";
    };

    windows = lib.mkOption {
      type = types.listOf (types.listOf (types.either types.str types.int));
      default = [
        # widget x y width height
        ["powermenu" 12 0 4 2]
        ["system" 0 2 4 3]
        ["time" 4 2 8 5]
        ["music" 0 5 4 2]
        ["shortcuts" 0 0 4 2]
        ["volume" 4 0 4 2]
        ["app_list" 12 2 4 7]
      ];
      description = "The widgets to display.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      eww
      playerctl
    ];

    xdg.configFile = {
      eww = {
        source = ./eww;
        recursive = true;
      };
      "eww/device_specific.yuck".text = ''
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
                    ${
          if cfg.device == "laptop"
          then ''
            (box :class "system_bat_bar" :orientation "v" :spacing 20 :space-evenly false :vexpand false :hexpand false
                (progress :value { EWW_BATTERY.total_avg } :orientation "v" :flipped true)
                (label :class "system_iconbat" :text "󰁹"))
          ''
          else ""
        })))

        ; shortcuts
        (defwidget shortcuts []
            (box :class "shortcuts dashboard_window" :orientation "v" :space-evenly false
                ${builtins.concatStringsSep "\n\t" (builtins.map (row: "(box :vexpand true :hexpand true\n${builtins.concatStringsSep "\n" (builtins.map (item: "\t\t(button :class \"shortcuts_button\" :onclick \"${at item 0} &\" \"${at item 1}\")") row)})") cfg.shortcuts)}))
      '';
      "eww/eww.yuck".text = ''
        (include "./dashboard.yuck")
        (include "./device_specific.yuck")

        ; windows
        ${builtins.concatStringsSep "\n" (builtins.map (win: ''
            (defwindow ${at win 0} :stacking "bottom" :focusable true :exclusive false :monitor 0
                :geometry (geometry :x ${str (grid.width * at win 1 + cfg.border)} :y ${str (grid.height * at win 2 + cfg.border)} :width ${str (grid.width * at win 3 - cfg.border * 2)} :height ${str (grid.height * at win 4 - cfg.border * 2)})
                    (${at win 0}))
          '')
          cfg.windows)}
      '';
    };
  };
}
