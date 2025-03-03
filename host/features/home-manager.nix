{
  inputs,
  outputs,
  lib,
  config,
  ...
}: {
  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs outputs;
      host-config = config;
    };
    users = builtins.listToAttrs (
      builtins.map
      (user: {
        inherit (user) name;
        value = {
          imports = [
            ../../home/features
            ../../home/${user.name}
          ];

          home.username = user.name;
        };
      })
      (builtins.filter (user: (builtins.pathExists
          ../../home/${user.name})) (lib.attrValues config.users.users))
    );
  };
}
