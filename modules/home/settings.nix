{lib, ...}: let
  monitor = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "The name of the monitor (e.g. HDMI-1)";
      };

      width = lib.mkOption {
        type = lib.types.int;
        description = "The width of the monitor in pixels.";
      };
      height = lib.mkOption {
        type = lib.types.int;
        description = "The height of the monitor in pixels.";
      };

      x = lib.mkOption {
        type = lib.types.int;
        description = "The x position of the monitor in pixels.";
      };
      y = lib.mkOption {
        type = lib.types.int;
        description = "The y position of the monitor in pixels.";
      };

      ratioX = lib.mkOption {
        type = lib.types.int;
        default = 16;
      };
      ratioY = lib.mkOption {
        type = lib.types.int;
        default = 9;
      };

      transform = lib.mkOption {
        type = lib.types.int;
        default = 0;
      };

      refreshRate = lib.mkOption {
        type = lib.types.int;
        default = 60;
      };
    };
  };
in {
  options.settings = {
    configPath = lib.mkOption {
      type = lib.types.path;
      default = /dotfiles;
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "default";
    };

    monitors = lib.mkOption {
      type = lib.types.listOf monitor;
      default = [];
      description = "A list of monitors to place widgets on, first monitor is the primary monitor.";
    };
  };
}
