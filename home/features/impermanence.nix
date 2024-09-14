{
  inputs,
  config,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  home.persistence."/persist/${config.home.homeDirectory}" = {
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
