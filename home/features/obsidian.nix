{
  pkgs,
  config,
  ...
}: {
  home = {
    packages = [pkgs.obsidian];
    persistence = {
      "/persist/data/${config.home.homeDirectory}".directories = [
        "vaults"
      ];
      "/persist/generated/${config.home.homeDirectory}".directories = [
        ".config/obsidian"
      ];
    };
  };
}
