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
      inputs.disko.nixosModules.disko
      inputs.stylix.nixosModules.stylix
    ]
    ++ (builtins.attrValues outputs.nixosModules);

  system.stateVersion = "24.05";
  users.mutableUsers = false;
}
