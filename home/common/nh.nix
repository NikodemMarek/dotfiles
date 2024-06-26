{
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [
    nh
  ];

  home.shellAliases = {
    swhome = "NIXPKGS_ALLOW_UNFREE=1 nh home switch ${config.settings.configPath} -- --impure";
  };
}
