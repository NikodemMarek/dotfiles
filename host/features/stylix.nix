{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  stylix = {
    enable = true;

    image = ../../assets/background.png;
    polarity = "dark";

    base16Scheme = import ../../assets/catppuccin-mocha.nix;

    fonts = {
      monospace = {
        package = pkgs.fira-code-nerdfont;
        name = "FiraCode Nerd Font";
      };
    };
  };
}
