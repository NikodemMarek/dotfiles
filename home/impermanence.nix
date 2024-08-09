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

      ".config/Google"

      ".local/share/keyrings"
      ".local/share/Google"

      ".cache"
    ];
    allowOther = true;
  };
}
