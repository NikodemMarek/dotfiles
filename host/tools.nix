{inputs, ...}: {
  imports = [
    inputs.nix-ld.nixosModules.nix-ld
  ];

  programs = {
    fish.enable = true;
    git.enable = true;
    nix-ld.dev.enable = true;
    ssh.startAgent = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
    direnv.enable = true;
  };
  environment.variables.EDITOR = "nvim";
}
