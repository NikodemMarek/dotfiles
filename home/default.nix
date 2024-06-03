{
  outputs,
  hostname,
  username,
  ...
}: {
  programs.home-manager.enable = true;

  imports = [
    ./modules/sops.nix
    ./modules/nh.nix
    ./modules/stylix.nix
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

    file.".ssh/id_ed25519_test".source = "/run/secrets/hosts/${hostname}/users/${username}/ssh_ed25519_priv";
  };

  systemd.user.startServices = "sd-switch";

  home.stateVersion = "23.11";
}
