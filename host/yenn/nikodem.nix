{pkgs, ...}: {
  imports = [
    ../features/optional/syncthing.nix
    ../features/optional/docker.nix
    ./persist.nix
  ];

  environment = {
    systemPackages = [
      pkgs.wrapped.gitui

      pkgs.alacritty
      pkgs.zen-browser
      pkgs.obsidian
      pkgs.ripgrep
      pkgs.eza
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
      pkgs.gemini-cli
      pkgs.nmap
      pkgs.tcpdump
      pkgs.lsof
      pkgs.neovim
      pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter

      pkgs.prismlauncher
      pkgs.heroic
      pkgs.steam
      pkgs.lutris
      pkgs.wine
      pkgs.winetricks
    ];
    shellAliases = {
      l = "eza -la --icons --group-directories-first --git";
      lt = "eza -laT --icons --group-directories-first --git";
      n = "nvim";
      g = "git";
      gi = "gitui";
      zj = "zellij";
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
      withUWSM = true;
      package = pkgs.wrapped.hyprland;
      portalPackage = pkgs.wrapped.hyprland;
      xwayland.enable = true;
    };
    hyprlock = {
      enable = true;
      package = pkgs.wrapped.hyprlock;
    };
  };

  sops.secrets = {
    "users/nikodem/ssh_id_ed25519" = {
      mode = "0400";
      owner = "nikodem";
      group = "users";
      path = "/home/nikodem/.ssh/id_ed25519";
    };
  };
  systemd.tmpfiles.rules = [
    "d /home/nikodem/.ssh 0700 nikodem users -"
    "L+ /home/nikodem/.ssh/id_ed25519.pub 0400 nikodem users - ${./user_nikodem_ssh_id_ed25519.pub}"
  ];

  services = {
    hypridle = {
      enable = true;
      package = pkgs.wrapped.hypridle;
    };
    printing = {
      enable = true;
      drivers = [pkgs.gutenprint];
    };
    syncthing.user = "nikodem";
  };
}
