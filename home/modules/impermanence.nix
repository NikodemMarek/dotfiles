{
  inputs,
  config,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  home.persistence."/persist/home/${config.settings.username}" = {
    directories = [
      "projects"
      "documents"
      "screenshots"

      ".ssh"
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
