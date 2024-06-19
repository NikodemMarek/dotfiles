{pkgs, ...}: {
  home.packages = with pkgs; [
    zip
    unzip
    bottom
    xxd
    fd
    ripgrep
  ];
}
