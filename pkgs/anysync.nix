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
    sha256 = "sha256-9g9r6z58i3ycTyN3rsoFX30pNKQk0dD1/quE4sty4pc=";
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
