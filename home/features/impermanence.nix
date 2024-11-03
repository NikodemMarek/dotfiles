{
  inputs,
  lib,
  config,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  options.persist = let
    inherit (lib) mkOption;
    inherit (lib.types) submodule listOf str;

    peristSub = {
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
    data = mkOption {
      type = submodule peristSub;
      default = {};
    };
    generated = mkOption {
      type = submodule peristSub;
      default = {};
    };
  };

  config = {
    home.persistence = {
      "/persist/data/${config.home.homeDirectory}" = {
        directories =
          [
            "projects"
            "documents"
            "screenshots"
          ]
          ++ config.persist.data.directories;
        files = config.persist.data.files;
        allowOther = true;
      };
      "/persist/generated/${config.home.homeDirectory}" = {
        directories =
          [
            ".config/Google"

            ".local/share/keyrings"
            ".local/share/Google"

            ".cache"
          ]
          ++ config.persist.generated.directories;
        files = config.persist.generated.files;
        allowOther = true;
      };
    };
  };
}
