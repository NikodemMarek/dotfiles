{pkgs ? (import ../nixpkgs.nix) {}}: {
  wrapped = {
    zellij = pkgs.callPackage ./zellij {};
    hyprlock = pkgs.callPackage ./hyprlock {};
    hypridle = pkgs.callPackage ./hypridle {};
  };
}
