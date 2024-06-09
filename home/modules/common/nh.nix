{
  pkgs,
  settings,
  ...
}: {
  home.packages = with pkgs; [
    nh
  ];

  home.shellAliases = {
    swhome = "NIXPKGS_ALLOW_UNFREE=1 nh home switch ${settings.configPath} -- --impure";
  };
}
