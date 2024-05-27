{pkgs ? (import ../nixpkgs.nix) {}}: {
  anysync = pkgs.callPackage ./anysync.nix {};

  solana-platform-tools = pkgs.callPackage ./solana-platform-tools.nix {};
  anchor-cli = pkgs.callPackage ./anchor-cli.nix {};
}
