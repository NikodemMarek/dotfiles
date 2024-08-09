{config, ...}: {
  home = {
    shellAliases = {
      d = "docker";
    };
    persistence."/persist/home/${config.home.username}".directories = [
      ".docker"
      ".dockercache"
    ];
  };
}
