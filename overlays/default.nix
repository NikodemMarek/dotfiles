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
    inherit (inputs.hyprland.packages.${prev.system}) hyprland;
    inherit (inputs.wezterm.packages.${prev.system}) wezterm;
    neovim = inputs.neovim.packages.${prev.system}.default;
    inherit (inputs.eww.packages.${prev.system}) eww;
    inherit (inputs.zen-browser.packages.${prev.system}) zen-browser;
    inherit (inputs.nix-ld.packages.${prev.system}) nix-ld;
    inherit (inputs.nixGL.packages.${prev.system}) nixGL;
    inherit (inputs.tuwunel.packages.${prev.system}) tuwunel;
    inherit (inputs.nixvirt.packages.${prev.system}) nixvirt;
  };
}
