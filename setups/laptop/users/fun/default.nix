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

  services = {
    battery-notifier = {
      enable = true;
      capacityPath = "/sys/class/power_supply/BAT1/capacity";
      statusPath = "/sys/class/power_supply/BAT1/status";
    };
  };

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
    persistence."/persist/${config.home}".directories = ["games"];
  };
}
