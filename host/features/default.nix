{outputs, ...}: {
  imports =
    [
      ./disko
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
