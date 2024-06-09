{
  imports = [
    ./zellij.nix
    ./direnv.nix
  ];

  programs = {
    starship.enable = true;
    zoxide.enable = true;
    fish = {
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
  };
}
