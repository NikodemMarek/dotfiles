{
  pkgs,
  host-config,
  ...
}: {
  home.packages = with pkgs;
    [
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
    ]
    ++ (
      lib.optional (host-config.hardware.bluetooth.enable) pkgs.bluetui
    );

  home.shellAliases = {
    cat = "bat -pp";
  };
}
