{
  inputs,
  outputs,
  ...
}: {
  imports =
    [
      ./disko
      ./sops.nix
      ./sudo.nix
      ./home-manager.nix
      ./time.nix
      ./stylix.nix
      ./networking.nix
      ./openssh.nix
      ./pipewire.nix
      ./greetd.nix
      ./tools.nix
      ./graphics.nix
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
