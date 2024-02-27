{ inputs
, outputs
, lib
, config
, pkgs
, utils
, hostname
, username
, settings
, ...
}: {
  programs.home-manager.enable = true;

  imports = [
    ./sops.nix
    ./assets
  ];

  xdg.configFile."../swhm.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      export NIXPKGS_ALLOW_UNFREE=1
      home-manager switch --flake /dotfiles#${username}@${hostname} --impure
    '';
  };

  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
      permittedInsecurePackages = [ ];
    };
  };

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
  };

  systemd.user.startServices = "sd-switch";

  home.stateVersion = "23.11";
}
