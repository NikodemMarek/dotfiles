{inputs, ...}: {
  additions = final: _prev: import ../pkgs {pkgs = final;};

  modifications = final: prev: {};

  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
      config.allowUnfreePredicate = _: true;
    };
  };

  inputs-packages = final: prev: {
    inherit (inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}) hyprland xdg-desktop-portal-hyprland;
    neovim = inputs.neovim.packages.${prev.stdenv.hostPlatform.system}.default;
    inherit (inputs.zen-browser.packages.${prev.stdenv.hostPlatform.system}) zen-browser;
  };

  deploy-rs = final: prev: {
    deploy-rs = {
      inherit (prev) deploy-rs;
      inherit ((inputs.deploy-rs.overlays.default final prev).deploy-rs) lib;
    };
  };
}
