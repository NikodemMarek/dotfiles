{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: {
  options.services.eww = let
    inherit (lib) mkOption mkEnableOption;
    inherit (lib.types) listOf attrs attrsOf int submodule;

    window.options = {
      grid = mkOption {
        type = listOf int;
      };
      args = mkOption {
        type = attrs;
        default = {};
      };
    };
  in {
    enable = mkEnableOption "Enable eww";

    border = mkOption {
      type = int;
      default = 10;
      description = "The border around the widgets.";
    };

    windows = mkOption {
      type = attrsOf (submodule window);
      default = {
        powermenu.grid = [12 0 4 2];
        system = {
          grid = [0 2 4 3];
          args = {
            battery = "true";
          };
        };
        clock.grid = [4 2 8 5];
        music.grid = [0 5 4 2];
        volume.grid = [4 0 4 2];
        app_list.grid = [12 2 4 7];
      };
    };
  };

  config = let
    cfg = config.services.eww;

    inherit (lib) mkIf getExe elemAt attrsToList;
    inherit (builtins) map concatStringsSep;

    eww = inputs.eww.packages.${pkgs.system}.default;
  in
    mkIf cfg.enable {
      home.packages = [
        eww

        pkgs.playerctl
        pkgs.wireplumber
      ];

      xdg.configFile = {
        eww = {
          source = ./eww;
          recursive = true;
        };
        "eww/eww.yuck".text = let
          inherit (cfg) border;

          cell = {
            width = 1920 / 16;
            height = 1080 / 9;
          };

          genIncludes = windows: concatStringsSep "\n" (map (win: ''(include "./${win.name}.yuck")'') (attrsToList windows));
          genGeometry = coords: ''(geometry :x ${toString (cell.width * elemAt coords 0 + border)} :y ${toString (cell.height * elemAt coords 1 + border)} :width ${toString (cell.width * elemAt coords 2 - border * 2)} :height ${toString (cell.height * elemAt coords 3 - border * 2)})'';
          genParams = args: concatStringsSep " " (map (param: ''${param.name}'') (attrsToList args));
          genArgs = args: concatStringsSep " " (map (arg: '':${arg.name} ${toString arg.name}'') (attrsToList args));
          genWindows = windows: concatStringsSep "\n" (map (win: ''(defwindow ${win.name} [${genParams win.value.args}] :stacking "bottom" :focusable false :exclusive false :monitor 0 :geometry ${genGeometry win.value.grid} (${win.name} ${genArgs win.value.args}))'') (attrsToList windows));
        in ''
          ${genIncludes cfg.windows}

          ${genWindows cfg.windows}
        '';
      };

      systemd.user.services.eww = {
        Install = {
          WantedBy = ["graphical-session.target"];
        };
        Service = {
          Type = "forking";
          ExecStart = let
            ewwExe = getExe eww;

            genArgs = args: concatStringsSep " " (map (arg: ''--arg ${arg.name}=${toString arg.value}'') (attrsToList args));
            genWindows = windows: concatStringsSep "\n" (map (win: ''${ewwExe} open ${win.name} ${genArgs win.value.args}'') (attrsToList windows));
          in
            getExe (pkgs.writeShellScriptBin "eww-execstart" ''
              ${ewwExe} daemon --force-wayland

              ${genWindows cfg.windows}
            '');
        };
      };
    };
}
