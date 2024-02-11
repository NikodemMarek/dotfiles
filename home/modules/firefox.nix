{ inputs, pkgs, ... }: {
    programs.firefox = {
        enable = true;
        profiles.main = {
            extensions = with inputs.firefox-addons.packages.${pkgs.system}; [
                ublock-origin
                darkreader
            ];
            settings = {
                "browser.shell.checkDefaultBrowser" = false;
                "browser.shell.defaultBrowserCheckCount" = 1;
            };
        };
    };
}
