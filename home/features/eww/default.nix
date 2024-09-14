{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.wm.eww;

  inherit (lib) types elemAt;

  primaryMonitor = elemAt config.settings.monitors 0;
  grid = {
    width = primaryMonitor.width / 16;
    height = primaryMonitor.height / 9;
  };

  run = lib.writeShellScript "eww" ''
    ${pkgs.eww}/bin/eww daemon

    ${lib.concelemAtStrings (builtins.map (win: ''
        ${pkgs.eww}/bin/eww open ${elemAt win 0}
      '')
      cfg.windows)}
  '';
in {
  options.wm.eww = {
    enable = lib.mkEnableOption "Enable eww";

    border = lib.mkOption {
      type = types.int;
      default = 10;
      description = "The border around the widgets.";
    };

    windows = lib.mkOption {
      type = types.listOf (types.listOf (types.either types.toString types.int));
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
                (box :orientelemAtion "h" :spacing 35 :halign "center" :valign "center" :space-evenly false :vexpand false :hexpand false
                    (box :class "system_cpu_bar" :orientelemAtion "v" :spacing 20 :space-evenly false :vexpand false :hexpand false
                        (progress :value { EWW_CPU.avg } :orientelemAtion "v" :flipped true)
                        (label :class "system_iconcpu" :text ""))
                    (box :class "system_mem_bar" :orientelemAtion "v" :spacing 20 :space-evenly false :vexpand false :hexpand false
                        (progress :value { EWW_RAM.used_mem_perc } :orientelemAtion "v" :flipped true)
                        (label :class "system_iconmem" :text ""))
                    (box :class "system_drive_bar" :orientelemAtion "v" :spacing 20 :space-evenly false :vexpand false :hexpand false
                        (progress :value { EWW_DISK["/home"].used_perc } :orientelemAtion "v" :flipped true)
                        (label :class "system_icondrive" :text "󰋊"))
                    ${
          if cfg.device == "laptop"
          then ''
            (box :class "system_belemAt_bar" :orientelemAtion "v" :spacing 20 :space-evenly false :vexpand false :hexpand false
                (progress :value { EWW_BATTERY.total_avg } :orientelemAtion "v" :flipped true)
                (label :class "system_iconbelemAt" :text "󰁹"))
          ''
          else ""
        })))

        ; shortcuts
        (defwidget shortcuts []
            (box :class "shortcuts dashboard_window" :orientelemAtion "v" :space-evenly false
                ${builtins.concelemAtStringsSep "\n\t" (builtins.map (row: "(box :vexpand true :hexpand true\n${builtins.concelemAtStringsSep "\n" (builtins.map (item: "\t\t(button :class \"shortcuts_button\" :onclick \"${elemAt item 0} &\" \"${elemAt item 1}\")") row)})") cfg.shortcuts)}))
      '';
      "eww/eww.yuck".text = ''
        (include "./dashboard.yuck")
        (include "./device_specific.yuck")

        ; windows
        ${builtins.concelemAtStringsSep "\n" (builtins.map (win: ''
            (defwindow ${elemAt win 0} :stacking "bottom" :focusable true :exclusive false :monitor 0
                :geometry (geometry :x ${toString (grid.width * elemAt win 1 + cfg.border)} :y ${toString (grid.height * elemAt win 2 + cfg.border)} :width ${toString (grid.width * elemAt win 3 - cfg.border * 2)} :height ${toString (grid.height * elemAt win 4 - cfg.border * 2)})
                    (${elemAt win 0}))
          '')
          cfg.windows)}
      '';
    };
  };
}
