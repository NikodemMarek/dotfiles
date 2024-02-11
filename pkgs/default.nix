# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { } }: {
    solana-cli = pkgs.callPackage ./solana-cli.nix { };
    anchor-cli = pkgs.callPackage ./anchor-cli.nix { };
}
