{pkgs ? (import ../nixpkgs.nix) {}}: {
  wrapped = {
    zellij = pkgs.callPackage ./zellij {};
    hyprland = pkgs.callPackage ./hyprland {};
    hyprlock = pkgs.callPackage ./hyprlock {};
    hypridle = pkgs.callPackage ./hypridle {};
    rofi = pkgs.callPackage ./rofi {};
    dunst = pkgs.callPackage ./dunst {};
    git = pkgs.callPackage ./git {};
    gitui = pkgs.callPackage ./gitui {};
    waybar = pkgs.callPackage ./waybar {};
  };
}
