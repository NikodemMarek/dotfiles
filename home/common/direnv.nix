{
  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };

    bash.enable = true;
  };

  home.shellAliases = {
    direnvenable = "echo use nix > .envrc; direnv allow";
  };
}
