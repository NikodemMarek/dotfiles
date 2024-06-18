{
  inputs,
  outputs,
  hostname,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    extraSpecialArgs = {
      inherit inputs outputs hostname;
      utils = import ../../utils;
    };
  };
}