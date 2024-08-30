{
  pkgs,
  config,
  ...
}: {
  imports = [
    ../../kanshi.nix

    ../../../../home
    ../../../../home/hyprland

    ../../../../home/neovim.nix
    ../../../../home/impermanence.nix
    ../../../../home/ssh.nix
    ../../../../home/beets.nix
    ../../../../home/yt-dlp.nix
  ];

  home = {
    packages = with pkgs; [
      rnote
      beeper
      zathura
      lutris
      prismlauncher
      jdk8
      steam
    ];
    persistence."/persist/${config.home.homeDirectory}".directories = [
      "games"

      ".local/share/PrismLauncher"
    ];
  };
}
