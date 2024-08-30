{config, ...}: {
  home = {
    shellAliases = {
      d = "docker";
    };
    persistence."/persist/${config.home.homeDirectory}".directories = [
      ".docker"
      ".dockercache"
    ];
  };
}
