{pkgs ? (import ../nixpkgs.nix) {}}: {
  wrapped = {
    zellij = pkgs.callPackage ./zellij {};
    hyprland = pkgs.callPackage ./hyprland {};
    hyprlock = pkgs.callPackage ./hyprlock {};
    hypridle = pkgs.callPackage ./hypridle {};
    hyprpaper = pkgs.callPackage ./hyprpaper {};
    rofi = pkgs.callPackage ./rofi {};
    dunst = pkgs.callPackage ./dunst {};
    git = pkgs.callPackage ./git {};
    gitui = pkgs.callPackage ./gitui {};
    waybar = pkgs.callPackage ./waybar {};
    kanshi = pkgs.callPackage ./kanshi {};
    gemini-cli = pkgs.callPackage ./gemini-cli {};
    claude-code = pkgs.callPackage ./claude-code {};
    signal-desktop = pkgs.callPackage ./signal-desktop {};
  };
}
