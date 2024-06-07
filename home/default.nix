{
  outputs,
  username,
  ...
}: {
  programs.home-manager.enable = true;

  imports = [
    ./modules/impermanence.nix
    ./modules/sops.nix
    ./modules/nh.nix
    ./modules/stylix.nix
    ./modules/ssh.nix
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
