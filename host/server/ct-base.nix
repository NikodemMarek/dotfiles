{
  inputs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops

    "${toString modulesPath}/virtualisation/proxmox-lxc.nix"
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "25.11";

  nix.settings.experimental-features = ["nix-command" "flakes"];
  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  boot.loader = {
    grub = {
      enable = lib.mkForce false;
      devices = ["nodev"];
    };
    systemd-boot.enable = lib.mkForce false;
  };
}
