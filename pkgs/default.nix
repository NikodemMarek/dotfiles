{pkgs ? (import ../nixpkgs.nix) {}}: {
  anysync = pkgs.callPackage ./anysync.nix {};
  fabric-ai = pkgs.callPackage ./fabric-ai.nix {};
}
