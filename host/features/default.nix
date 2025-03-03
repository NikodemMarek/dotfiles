{
  inputs,
  outputs,
  ...
}: {
  imports =
    [
      inputs.sops-nix.nixosModules.sops
      inputs.impermanence.nixosModules.impermanence
      inputs.nix-ld.nixosModules.nix-ld
      inputs.home-manager.nixosModules.home-manager
      inputs.disko.nixosModules.disko
      inputs.stylix.nixosModules.stylix

      ./time.nix
      ./stylix.nix
      ./networking.nix
      ./openssh.nix
      ./tools.nix
      ./graphics.nix
      ./security.nix
      ./nix.nix
    ]
    ++ (builtins.attrValues outputs.nixosModules);
}
