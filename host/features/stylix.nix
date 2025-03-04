{pkgs, ...}: {
  stylix = {
    enable = true;

    image = ../../assets/background.png;
    polarity = "dark";

    base16Scheme = import ../../assets/catppuccin-mocha.nix;

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font";
      };
    };
  };
}
