{
  inputs,
  outputs,
  lib,
  config,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs outputs;
    };
    users = builtins.listToAttrs (
      builtins.map
      (user: {
        inherit (user) name;
        value = {
          imports = [
            ../setups/${config.networking.hostName}/users/${user.name}
          ];

          home.username = user.name;

          settings =
            {
              hostname = config.networking.hostName;
            }
            // config.settings;
        };
      })
      (builtins.filter (user: (builtins.pathExists
          ../setups/${config.networking.hostName}/users/${user.name})) (lib.attrValues config.users.users))
    );
  };
}
