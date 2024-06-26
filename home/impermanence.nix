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

      ".local/share/keyrings"
      ".local/share/direnv"
      ".local/share/nvim"

      ".cache"
      ".mozilla"
      ".npm"
      ".cargo"
      ".java"
      ".hyprland"
      ".gradle"
      ".docker"
      ".dockercache"
    ];
    files = [
      ".local/share/fish/fish_history"
      ".local/share/zoxide/db.zo"
    ];
    allowOther = true;
  };
}
