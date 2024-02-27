{ pkgs ? import <nixpkgs> {}, rustPlatform }:

rustPlatform.buildRustPackage rec {
    pname = "anchor-cli";
    version = "0.29.0";

    src = pkgs.fetchFromGitHub {
        owner = "coral-xyz";
        repo = "anchor";
        rev = "master";
        sha256 = "sha256-4kax0FU1PM5/kAFRWVCrucE5uo339h/AaCBlQm2ulNs=";
    };

    cargoLock = {
        lockFile = "${src}/Cargo.lock";
        outputHashes = {
            "serum_dex-0.4.0" = "sha256-Nzhh3OcAFE2LcbUgrA4zE2TnUMfV0dD4iH6fTi48GcI=";
        };
    };

    cargoSha256 = "";

    doCheck = false;
    buildArgs = [
        "-p"
        "anchor-cli"
    ];

    meta = with pkgs.lib; {
        description = "Anchor is a framework for Solana's Sealevel runtime providing several convenient developer tools for writing smart contracts.";
    };
}
