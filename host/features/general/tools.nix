{
  programs = {
    fish.enable = true;
    git.enable = true;
    ssh.startAgent = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
  };
  environment.variables.EDITOR = "nvim";
}
