{config, ...}: {
  home = {
    shellAliases = {
      d = "docker";
    };
    persistence."/persist/${config.home}".directories = [
      ".docker"
      ".dockercache"
    ];
  };
}
