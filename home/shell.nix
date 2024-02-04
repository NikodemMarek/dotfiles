{ config, pkgs, lib, ... }: {
  imports = [
    ./zellij.nix
    ./direnv.nix
  ];

  programs.starship.enable = true;
  programs.zoxide.enable = true;
  programs.eza.enable = true;

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
  };
}
