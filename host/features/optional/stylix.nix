{pkgs, ...}: {
  stylix = {
    enable = true;

    image = pkgs.wallpaper;
    polarity = "dark";

    base16Scheme = import ./catppuccin-mocha.nix;

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font";
      };
    };
  };
}
