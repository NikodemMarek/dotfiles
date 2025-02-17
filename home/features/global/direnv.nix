{
  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };

    bash.enable = true;
  };

  persist.generated.directories = [
    ".local/share/direnv"
  ];
}
