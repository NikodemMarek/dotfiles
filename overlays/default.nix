{inputs, ...}: {
  additions = final: _prev: import ../pkgs {pkgs = final;};

  modifications = final: prev: {};

  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs {
      system = final.system;
      config.allowUnfree = true;
      config.allowUnfreePredicate = _: true;
    };
  };

  inputs-packages = final: prev: {
    inherit (inputs.hyprland.packages.${prev.system}) hyprland xdg-desktop-portal-hyprland;
    neovim = inputs.neovim.packages.${prev.system}.default;
    inherit (inputs.zen-browser.packages.${prev.system}) zen-browser;
  };
}

