{
  inputs,
  config,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  home.persistence."/persist/${config.home}" = {
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
