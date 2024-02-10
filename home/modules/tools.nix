{ config, pkgs, lib, ... }: {
  home.packages = with pkgs; [
    zip unzip
    bottom
    xxd
  ];
}
