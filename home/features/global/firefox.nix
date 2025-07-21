{
  inputs,
  pkgs,
  config,
  ...
}: {
  programs.firefox = {
    enable = true;
    profiles.main = {
      extensions.packages = with inputs.firefox-addons.packages.${pkgs.system}; [
        ublock-origin
        darkreader
        # languagetool
        simple-translate
        vimium
      ];
      settings = {
        "browser.shell.checkDefaultBrowser" = false;
        "browser.shell.defaultBrowserCheckCount" = 1;
        "browser.download.dir" = "${config.home.homeDirectory}/tmp";
      };
    };
  };

  stylix.targets.firefox.profileNames = ["main"];
}
