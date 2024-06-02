{
  inputs,
  settings,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    (import ./device-btrfs-persistence.nix {
      device = settings.drive;
      inherit (settings) swap;
    })
  ];
}
