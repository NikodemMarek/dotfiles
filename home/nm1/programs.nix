{
  pkgs,
  config,
  ...
}: {
  programs = {
    starship = {
      enable = true;
      enableNushellIntegration = true;
    };
    zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };
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
    direnv = {
      enable = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
      nix-direnv.enable = true;
    };

    bash.enable = true;
  };

  home = {
    sessionVariables = {
      JAVA_8_HOME = "${pkgs.jdk8}";
      JAVA_11_HOME = "${pkgs.jdk11}";
      JAVA_21_HOME = "${pkgs.jdk21}";
      JAVA_25_HOME = "${pkgs.jdk25}";
    };
    shellAliases = {
      n = "nvim";
      g = "git";
      gi = "gitui";
      zi = "zellij";
      l = "eza -la --icons --group-directories-first --git";
      lt = "eza -laT --icons --group-directories-first --git";
      cat = "bat -pp";
    };
    packages = [
      pkgs.wrapped.zellij
      pkgs.wrapped.waybar
      pkgs.wrapped.rofi
      pkgs.wrapped.dunst
      pkgs.wrapped.git
      pkgs.wrapped.gitui
      pkgs.wrapped.kanshi
      pkgs.alacritty
      pkgs.neovim
      pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter
      pkgs.obsidian

      pkgs.kubectl
      pkgs.sshpass
      pkgs.remmina
      (config.lib.nixGL.wrap pkgs.google-chrome)
      pkgs.android-studio
      pkgs.jetbrains.idea-ultimate
      pkgs.dbeaver-bin
      pkgs.oracle-instantclient
      pkgs.glab
      pkgs.rainfrog
      pkgs.claude-code
      pkgs.gemini-cli
      pkgs.maven
      pkgs.nodejs
      pkgs.pnpm
      pkgs.python3
      pkgs.gcc
      pkgs.eza
      pkgs.bat
      pkgs.jq
      pkgs.zip
      pkgs.unzip
      pkgs.bottom
      pkgs.xxd
      pkgs.fd
      pkgs.ripgrep
      pkgs.bat
      pkgs.feh
      pkgs.tldr
      pkgs.openssl
      pkgs.rnote
      pkgs.zathura
      pkgs.kooha
      pkgs.bluetui
    ];
  };
}
