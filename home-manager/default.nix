{ inputs
, outputs
, lib
, config
, pkgs
, hostname
, username
, programs
, settings
, ...
}:
let
  rw = builtins.partition (p: builtins.pathExists ./${ p } || builtins.pathExists ./${ p }.nix) programs;
  preconfigured = rw.right;
  extra = rw.wrong;
in
{
  programs.home-manager.enable = true;

  imports = [
    ./git.nix
  ] ++ builtins.map (p: if builtins.pathExists ./${ p } then ./${ p } else ./${p}.nix) preconfigured;

  home.packages = builtins.map (e: pkgs.${e}) extra;

  xdg.configFile."assets/background.png".source = ./assets/background.png;
  xdg.configFile."../swhm.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      home-manager switch --flake /dotfiles#${username}@${hostname}
    '';
  };

  xdg.configFile."autorun.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      ${lib.concatStrings (builtins.map (p: if builtins.pathExists ./${ p }/autorun.nix then import ./${ p }/autorun.nix { inherit lib; } else "") programs)}
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
      permittedInsecurePackages = [ "nodejs-16.20.2" ];
    };
  };

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}
