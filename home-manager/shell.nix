{ config, pkgs, lib, ... }: {
  imports = [
    ./zellij.nix
  ];

  programs.starship.enable = true;
  programs.zoxide.enable = true;
  programs.eza.enable = true;
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Fully clear console.
      function fish_user_key_bindings
        bind \cl 'clear; commandline -f repaint'
      end

      function fish_greeting
      end
    '';
    shellAliases = {
      zop = "zellij -l 'project'";
    };
  };
}
