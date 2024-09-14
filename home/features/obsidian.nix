{
  pkgs,
  config,
  ...
}: {
  home = {
    packages = [pkgs.obsidian];
    persistence."/persist/${config.home.homeDirectory}".directories = [
      "vaults"
      ".config/obsidian"
    ];
  };
}
