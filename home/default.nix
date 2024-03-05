{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  utils,
  hostname,
  username,
  settings,
  ...
}: {
  programs.home-manager.enable = true;

  imports = [
    ./sops.nix
    ./assets
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
      permittedInsecurePackages = [];
    };
  };

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    shellAliases = {
      swhome = "NIXPKGS_ALLOW_UNFREE=1 home-manager switch --flake /dotfiles#${username}@${hostname} --impure";
    };
  };

  systemd.user.startServices = "sd-switch";

  home.stateVersion = "23.11";
}
