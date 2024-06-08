{
  inputs,
  username,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  home.persistence."/persist/home/${username}" = {
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
