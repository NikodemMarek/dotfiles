{pkgs, ...}: {
  home = {
    packages = with pkgs; [
      # cpp
      gcc

      # python
      python3

      # rust
      # rustup
      cargo
      rustc
      rustfmt

      # node
      nodejs
      pnpm

      # java
      maven
      jdk25

      # go
      go

      # other
      wasm-pack

      # utilities
      watchexec
    ];
  };

  programs.bun.enable = true;
}
