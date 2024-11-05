{
  inputs,
  lib,
  host-config,
  config,
  ...
}: {
  imports = [
    ../shared/persist.nix

    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  config = let
    host-cfg = host-config.persist;
    cfg = config.persist;

    inherit (lib) mkIf;
  in
    mkIf (host-cfg.enable || cfg.enable) {
      home.persistence = {
        "/persist/data/${config.home.homeDirectory}" = {
          directories =
            [
              "projects"
              "documents"
              "screenshots"
            ]
            ++ cfg.data.directories;
          files = cfg.data.files;
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
            ++ cfg.generated.directories;
          files = cfg.generated.files;
          allowOther = true;
        };
      };
    };
}
