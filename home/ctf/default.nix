{
  pkgs,
  host-config,
  config,
  ...
}: {
  imports = [
    ../../host/${host-config.networking.hostName}/kanshi.nix

    ../features/hyprland

    ../features/neovim.nix
    ../features/impermanence.nix
    ../features/docker.nix
    ../features/obsidian.nix
    ../features/fabric-ai.nix
    ../features/ollama.nix
  ];

  programs = {
    git = {
      userEmail = "nikodemmarek11@gmail.com";
      userName = "NikodemMarek";
    };
  };

  home = {
    packages = with pkgs; [
      rnote
      beeper
      typst
      zathura
      xh
      openssl
    ];
    persistence."/persist/${config.home.homeDirectory}".directories = [
    ];
  };
}