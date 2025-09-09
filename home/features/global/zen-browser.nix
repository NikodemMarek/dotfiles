{
  inputs,
  pkgs,
  config,
  ...
}: {
  home.packages = [
    (config.lib.nixGL.wrap inputs.zen-browser.packages."${pkgs.system}".default)
  ];
}
