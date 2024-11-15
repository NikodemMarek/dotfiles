{pkgs ? (import ../nixpkgs.nix) {}}: {
  anysync = pkgs.callPackage ./anysync.nix {};
}
