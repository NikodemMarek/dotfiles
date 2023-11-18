{ inputs
, outputs
, lib
, config
, pkgs
, device
, resolution
, username
, extraPkgs
, programs
, workDir
, email
, name
, ...
}: {
  programs.home-manager.enable = true;

  imports = [
    ./git.nix
  ] ++ builtins.map (p: ./${ p }) programs;

  xdg.configFile."assets/background.png".source = ./assets/background.png;

  # FIXME: This is currently broken & I have no idea how to fix it, nice
  xdg.configFile."autorun.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
    '';
    # text = ''
    #   #!/bin/sh
    #   
    #   ${lib.concatMapStrings ( m: m.autorun or "" ) modules}
    # '';
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
