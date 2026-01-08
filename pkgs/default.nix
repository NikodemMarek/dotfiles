{pkgs ? (import ../nixpkgs.nix) {}}: {
  wrapped = {
    zellij = pkgs.callPackage ./zellij {};
    hypridle = pkgs.callPackage ./hypridle {};
  };
}
