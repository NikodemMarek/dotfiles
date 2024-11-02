{
  inputs,
  config,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  home.persistence = {
    "/persist/data/${config.home.homeDirectory}" = {
      directories = [
        "projects"
        "documents"
        "screenshots"
      ];
      allowOther = true;
    };
    "/persist/generated/${config.home.homeDirectory}" = {
      directories = [
        ".config/Google"

        ".local/share/keyrings"
        ".local/share/Google"

        ".cache"
      ];
      allowOther = true;
    };
  };
}
