{
  pkgs,
  config,
  ...
}: {
  imports = [
    ../../kanshi.nix

    ../../../../home
    ../../../../secrets
    ../../../../home/hyprland

    ../../../../home/neovim.nix
    ../../../../home/impermanence.nix
    ../../../../home/ssh.nix
    ../../../../home/docker.nix
    ../../../../home/obsidian.nix
    ../../../../home/fabric-ai.nix
    ../../../../home/ollama.nix
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
