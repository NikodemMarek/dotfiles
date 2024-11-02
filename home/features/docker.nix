{config, ...}: {
  home = {
    shellAliases = {
      d = "docker";
    };
    persistence."/persist/generated/${config.home.homeDirectory}".directories = [
      ".docker"
      ".dockercache"
    ];
  };
}
