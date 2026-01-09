{pkgs ? (import ../nixpkgs.nix) {}}: {
  wrapped = {
    zellij = pkgs.callPackage ./zellij {};
    hyprland = pkgs.callPackage ./hyprland {};
    hyprlock = pkgs.callPackage ./hyprlock {};
    hypridle = pkgs.callPackage ./hypridle {};
    git = pkgs.callPackage ./git {};
    gitui = pkgs.callPackage ./gitui {};
  };
}
