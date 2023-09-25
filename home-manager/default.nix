{ inputs, outputs, lib, config, pkgs, username, extraPkgs, workDir, ... }:
let
  modules = builtins.map ( name:
    import ./${name} {
      inherit config pkgs lib;
      inherit workDir;
      resolution = { width = 1920; height = 1080; };
    }
  ) [ "eww" "neovim" "hypr" ];
in {
  imports = [
    ./shell.nix
    ./alacritty.nix
  ] ++ builtins.map ( m: m.module ) modules;

  home.packages = builtins.map ( name: pkgs.${name} ) ( extraPkgs ++ ( lib.lists.flatten ( builtins.map ( m: m.extraPkgs ) modules ) ) );

  programs.home-manager.enable = true;
  programs.git.enable = true;
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
