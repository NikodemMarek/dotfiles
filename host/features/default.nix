{
  inputs,
  outputs,
  ...
}: {
  imports =
    [
      ./global

      inputs.sops-nix.nixosModules.sops
      inputs.impermanence.nixosModules.impermanence
      inputs.nix-ld.nixosModules.nix-ld
      inputs.home-manager.nixosModules.home-manager
      inputs.disko.nixosModules.disko
      inputs.stylix.nixosModules.stylix
    ]
    ++ (builtins.attrValues outputs.nixosModules);

  system.stateVersion = "24.05";
}
