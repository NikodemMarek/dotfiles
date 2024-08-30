{
  pkgs,
  config,
  ...
}: {
  home = {
    packages = [pkgs.obsidian];
    persistence."/persist/${config.home}".directories = [
      "vaults"
      ".config/obsidian"
    ];
  };

  services.syncthing = {
    enable = true;
  };
}
