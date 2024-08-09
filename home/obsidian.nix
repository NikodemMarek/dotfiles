{
  pkgs,
  config,
  ...
}: {
  home = {
    packages = [pkgs.obsidian];
    persistence."/persist/home/${config.home.username}".directories = [
      "vaults"
      ".config/obsidian"
    ];
  };
}
