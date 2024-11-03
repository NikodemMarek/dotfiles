{
  pkgs,
  lib,
  host-config,
  ...
}: {
  imports = [
    ../../host/${host-config.networking.hostName}/kanshi.nix

    ../features/hyprland

    ../features/neovim.nix
    ../features/ssh.nix
    ../features/docker.nix
    ../features/beets.nix
    ../features/yt-dlp.nix
    ../features/obsidian.nix
    ../features/fabric-ai.nix
    ../features/ollama.nix
  ];

  services =
    {}
    // lib.mkIf (host-config.networking.hostName == "laptop") {
      battery-notifier = {
        enable = true;
        capacityPath = "/sys/class/power_supply/BAT1/capacity";
        statusPath = "/sys/class/power_supply/BAT1/status";
      };
    };

  programs = {
    git = {
      userEmail = "nikodemmarek11@gmail.com";
      userName = "NikodemMarek";
    };
  };

  home.packages = with pkgs; [
    rnote
    beeper
    typst
    zathura
    xh
  ];

  persist = {
    generated.directories = [
      ".config/JetBrains"

      ".local/share/JetBrains"
    ];
    data.directories = lib.optional host-config.virtualisation.virtualbox.host.enable "vms";
  };
}
