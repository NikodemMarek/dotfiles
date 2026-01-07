{
  imports = [
    ./networking.nix
    ./nix.nix
    ./openssh.nix
    ./sops.nix
    ./stylix.nix
  ];

  programs = {
    git.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
  };
  environment.variables.EDITOR = "nvim";
  security.sudo.enable = true;
}
