{
  inputs,
  pkgs,
  config,
  ...
}: {
  programs.firefox = {
    enable = true;
    profiles.main = {
      extensions = with inputs.firefox-addons.packages.${pkgs.system}; [
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

  home.persistence."/persist/${config.home.homeDirectory}".directories = [
    ".mozilla"
  ];
}
