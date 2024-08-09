{pkgs, ...}: {
  imports = [
    ../../../../home
    ../../../../home/neovim
    ../../../../home/hyprland

    ../../../../home/impermanence.nix
    ../../../../home/ssh.nix
    ../../../../home/docker.nix
    ../../../../home/beets.nix
    ../../../../home/yt-dlp.nix
    ../../../../home/obsidian.nix
  ];

  programs = {
    git = {
      userEmail = "nikodemmarek11@gmail.com";
      userName = "NikodemMarek";
    };
  };

  home = {
    packages = with pkgs; [
      rnote
      beeper
      typst
      zathura
      xh
      android-studio
    ];
    persistence."/persist/home/nikodem".directories = [
      ".config/JetBrains"

      ".local/share/JetBrains"
    ];
  };
}
