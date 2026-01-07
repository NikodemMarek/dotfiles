{pkgs ? (import ../nixpkgs.nix) {}}: {
  wrapped = {
    zellij = pkgs.callPackage ./zellij {};
  };
}
