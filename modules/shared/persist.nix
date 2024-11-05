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

    device = mkOption {
      description = "Name of the device to use for persisting data";
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
