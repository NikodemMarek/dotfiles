{lib, ...}: {
  options.persist = let
    inherit (lib) mkEnableOption mkOption;
    inherit (lib.types) submodule listOf str;

    peristentCategory = {
      options = {
        directories = mkOption {
          type = listOf str;
          default = [];
        };
        files = mkOption {
          type = listOf str;
          default = [];
        };
      };
    };
  in {
    enable = mkEnableOption "Enable impermanence";

    deviceService = mkOption {
      description = "Systemd device service to wait for, before pruning";
      type = str;
    };
    rootPath = mkOption {
      description = "Root device path";
      type = str;
    };

    # TODO: Allow arbitrary number of categories
    data = mkOption {
      type = submodule peristentCategory;
      default = {};
    };
    generated = mkOption {
      type = submodule peristentCategory;
      default = {};
    };
  };
}
