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
    allowOther = true;
  };
}
