{
  imports = [
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

        fish_vi_key_bindings
      '';
    };
  };

  persist.generated = {
    directories = [
      ".local/share/zoxide"
    ];
    files = [
      ".local/share/fish/fish_history"
    ];
  };
}
