{pkgs, ...}: {
  environment = {
    systemPackages = [
      pkgs.obsidian
      pkgs.ripgrep
      pkgs.eza
      pkgs.wrapped.gitui
      pkgs.jq
      pkgs.zip
      pkgs.unzip
      pkgs.bottom
      pkgs.xxd
      pkgs.fd
      pkgs.bat
      pkgs.feh
      pkgs.tldr
      pkgs.openssl
      pkgs.rnote
      pkgs.zathura
      pkgs.kooha
      pkgs.bluetui
      pkgs.yazi

      pkgs.neovim
      pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter
    ];
    shellAliases = {
      l = "eza -la --icons --group-directories-first --git";
      lt = "eza -laT --icons --group-directories-first --git";
      n = "nvim";
      g = "git";
      gi = "gitui";
    };
  };

  programs = {
    git = {
      enable = true;
      package = pkgs.wrapped.git;
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
      enableFishIntegration = true;
      nix-direnv.enable = true;
    };
    zoxide = {
      enable = true;
      enableFishIntegration = true;
      enableBashIntegration = true;
    };
    starship.enable = true;
    hyprland = {
      enable = true;
      # withUWSM = true;
      package = pkgs.wrapped.hyprland;
      portalPackage = pkgs.wrapped.hyprland;
      xwayland.enable = true;
    };
    hyprlock = {
      enable = true;
      package = pkgs.wrapped.hyprlock;
    };
  };

  security.rtkit.enable = true;
  services = {
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --cmd Hyprland -r -t";
        };
      };
    };
    hypridle = {
      enable = true;
      package = pkgs.wrapped.hypridle;
    };
  };
}
