{
  outputs,
  hostname,
  ...
}: {
  imports = [
    ./${hostname}/hardware-configuration.nix

    ./modules/sops.nix
    ./modules/stylix.nix
    ./modules/networking.nix
    ./modules/dnscrypt-proxy2.nix
    ./modules/docker.nix
    ./modules/openssh.nix
    ./modules/pipewire.nix
    ./modules/greetd.nix
    ./modules/tools.nix
    ./modules/hyprland.nix
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];

  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
    config = {
      allowUnfree = true;
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
