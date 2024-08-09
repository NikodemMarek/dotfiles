{lib, ...}: {
  options.settings = {
    configPath = lib.mkOption {
      type = lib.types.str;
      default = "/dotfiles";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
    };
  };
}
