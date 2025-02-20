{
  inputs,
  pkgs,
  ...
}: let
  neovim = inputs.neovim.packages.${pkgs.system}.default.extend {};
in {
  programs = {
    ripgrep.enable = true;
    neovim.defaultEditor = true;
  };

  home = {
    packages = [
      neovim
      pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter
    ];
    shellAliases = {
      n = "nvim";
    };
  };
}
