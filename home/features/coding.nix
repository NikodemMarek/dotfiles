{pkgs, ...}: {
  home = {
    packages = with pkgs; [
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

      # utilities
      watchexec
    ];
    shellAliases = {
      wth = "watchexec --exts rs,go,py,sh,c,cpp,h,js,ts,tsx,css,html,java,wasm --restart --debounce 1000ms --shell bash -- $1";
    };
  };
}
