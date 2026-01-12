{pkgs ? (import ../nixpkgs.nix) {}}: {
  wrapped = {
    zellij = pkgs.callPackage ./zellij {};
    hyprland = pkgs.callPackage ./hyprland {};
    hyprlock = pkgs.callPackage ./hyprlock {};
    hypridle = pkgs.callPackage ./hypridle {};
    hyprlauncher = pkgs.callPackage ./hyprlauncher {};
    git = pkgs.callPackage ./git {};
    gitui = pkgs.callPackage ./gitui {};
  };
}
