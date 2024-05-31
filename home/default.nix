{
  outputs,
  username,
  ...
}: {
  programs.home-manager.enable = true;

  imports = [
    ./sops.nix
    ./modules/nh.nix
    ../modules/stylix.nix
  ];

  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
    config = {
      allowUnfree = true;
      allowUnfreePredicate = _: true;
    };
  };

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
  };

  systemd.user.startServices = "sd-switch";

  home.stateVersion = "23.11";
}
