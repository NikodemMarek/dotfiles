{pkgs, ...}: {
  home.packages = with pkgs; [
    # cpp
    gcc

    # python
    python3

    # rust
    cargo
    rustc
    rustfmt

    # node
    nodejs
    pnpm

    # java
    maven

    # go
    go

    # other
    wasm-pack
  ];
}
