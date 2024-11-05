{pkgs, ...}: {
  home.packages = with pkgs; [
    jq
    zip
    unzip
    bottom
    xxd
    fd
    ripgrep
    bat
    feh
  ];

  home.shellAliases = {
    cat = "bat -pp";
  };
}
