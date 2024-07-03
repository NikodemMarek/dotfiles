{
  inputs,
  config,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  home.persistence."/persist/home/${config.home.username}" = {
    directories = [
      "projects"
      "documents"
      "screenshots"

      ".config/Rocket.Chat"
      ".config/JetBrains"
      ".config/github-copilot"
      ".config/Google"

      ".local/share/keyrings"
      ".local/share/direnv"
      ".local/share/nvim"
      ".local/share/gh"
      ".local/share/zoxide"
      ".local/share/JetBrains"

      ".cache"
      ".mozilla"
      ".npm"
      ".cargo"
      ".java"
      ".hyprland"
      ".gradle"
      ".docker"
      ".m2"
      ".dockercache"
    ];
    files = [
      ".ssh/known_hosts"

      ".config/sops/age/keys.txt"

      ".local/share/fish/fish_history"
    ];
    allowOther = true;
  };
}
