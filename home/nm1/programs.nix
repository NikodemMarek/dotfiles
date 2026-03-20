{
  lib,
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
      za = lib.getExe (pkgs.writeShellScriptBin "zellij-attach" ''
        SELECTED=$(zellij list-sessions --no-formatting | fzf | awk '{print $1}')
        zellij attach $SELECTED
      '');
      l = "eza -la --icons --group-directories-first --git";
      lt = "eza -laT --icons --group-directories-first --git";
      cat = "bat -pp";
    };
    packages = [
      pkgs.wrapped.zellij
      pkgs.wrapped.waybar
      pkgs.wrapped.rofi
      pkgs.wrapped.dunst
      pkgs.wrapped.gitui
      pkgs.wrapped.kanshi
      pkgs.alacritty
      pkgs.neovim
      pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter

      (config.lib.nixGL.wrap pkgs.google-chrome)
      pkgs.android-studio
      pkgs.pnpm
      pkgs.eza
      pkgs.bat
      pkgs.jq
      pkgs.zip
      pkgs.unzip
      pkgs.bottom
      pkgs.xxd
      pkgs.fd
      pkgs.fzf
      pkgs.ripgrep
      pkgs.bat
      pkgs.feh
      pkgs.tldr
      pkgs.kooha
      pkgs.bluetui
    ];
  };
}
