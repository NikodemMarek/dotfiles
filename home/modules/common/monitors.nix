{lib, ...}: {
  options.monitors = lib.mkOption {
    type = lib.types.listOf (lib.types.attrsOf {
      name = lib.types.str;

      width = lib.types.int;
      height = lib.types.int;

      x = lib.types.int;
      y = lib.types.int;

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
    });
    default = [];
    description = "A list of monitors to place widgets on, first monitor is the primary monitor.";
  };
}
