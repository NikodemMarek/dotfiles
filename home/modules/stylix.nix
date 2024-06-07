{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.stylix.homeManagerModules.stylix
  ];

  stylix = {
    image = ../../assets/background.png;
    polarity = "dark";

    base16Scheme = import ../../assets/catppuccin-mocha.nix;

    fonts = {
      monospace = {
        package = pkgs.hack-font;
        name = "Hack";
      };
    };
  };
}
