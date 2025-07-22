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
    tldr
    openssl
    xh
    rnote
    beeper
    typst
    zathura
    kooha
    postman
    bluetui
  ];

  home.shellAliases = {
    cat = "bat -pp";
  };
}
