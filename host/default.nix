{
  inputs,
  outputs,
  hostname,
  ...
}: {
  imports =
    [
      ./${hostname}/hardware-configuration.nix
      (import ./modules/users.nix (import ./${hostname}/users.nix))

      ./modules/disko
      ./modules/home-manager.nix
      ./modules/time.nix
      ./modules/stylix.nix
      ./modules/networking.nix
      ./modules/openssh.nix
      ./modules/pipewire.nix
      ./modules/greetd.nix
      ./modules/tools.nix
      ./modules/graphics.nix
    ]
    ++ (builtins.attrValues outputs.nixosModules);

  nix.settings.experimental-features = ["nix-command" "flakes"];

  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      inputs.wired.overlays.default
    ];
    config = {
      allowUnfree = true;
      allowUnfreePredicate = _: true;
    };
  };

  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 30;
    timeout = 0;
  };

  security.protectKernelImage = false;

  system.stateVersion = "23.11";
}
