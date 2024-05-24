# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'
{pkgs ? (import ../nixpkgs.nix) {}}: {
  anysync = pkgs.callPackage ./anysync.nix {};

  solana-platform-tools = pkgs.callPackage ./solana-platform-tools.nix {};
  anchor-cli = pkgs.callPackage ./anchor-cli.nix {};
}
