{
  pkgs ? import <nixpkgs> {},
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "anysync";
  version = "0.1.0";

  src = pkgs.fetchFromGitHub {
    owner = "NikodemMarek";
    repo = "anysync";
    rev = "main";
    sha256 = "sha256-+uhEwQ+/OHCSGF+9x6Fdf2EWvdHc1SXEB/aTJc4y3UQ=";
  };

  nativeBuildInputs = with pkgs; [pkg-config];
  buildInputs = with pkgs; [
    gcc
    openssl
  ];

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };
}
