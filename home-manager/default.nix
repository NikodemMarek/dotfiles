{
  inputs, outputs, lib, config, pkgs,
  username, extraPkgs, workDir, resolution, email, name,
  ...
}:
let
  modules = builtins.map ( name:
    import ./${name} {
      inherit config pkgs lib;
      inherit workDir resolution name email;
    }
  ) [ "eww" "neovim" "hypr" "gtklock.nix" "git.nix" ];
in {
  xdg.configFile."assets/background.png".source = ./assets/background.png;

  imports = [
    ./shell.nix
    ./alacritty.nix
  ] ++ builtins.map ( m: m.module ) modules;

  home.packages = builtins.map ( name: pkgs.${name} ) ( extraPkgs ++ ( lib.lists.flatten ( builtins.map ( m: m.extraPkgs ) modules ) ) );

  programs.home-manager.enable = true;
  programs.neovim.enable = true;
  programs.firefox.enable = true;
  programs.gitui.enable = true;
  programs.eza.enable = true;
  programs.joshuto.enable = true;

  xdg.configFile."autorun.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      
      ${lib.concatMapStrings ( m: m.autorun or "" ) modules}
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
