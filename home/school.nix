{
    settings = {
        name = "nikodem";
        email = "nikodemmarek11@gmail.com";
        eww = {
            shortcuts = [
                [
                    [ "firefox" "" ]
                    [ "qutebrowser" "󰖟" ]
                ]
                [
                    [ "android-studio" "as" ]
                    [ "beeper --default-frame" "󰵅" ]
                ]
            ];
        };
    };

    module = { inputs
    , outputs
    , lib
    , config
    , pkgs
    , ...
    }: {
        imports = [
            ./modules/neovim
            ./modules/hyprland
            ./modules/eww

            ./modules/git.nix
            ./modules/tools.nix
            ./modules/firefox.nix
            ./modules/qutebrowser.nix
        ];

        home.packages = with pkgs; [
            beeper
            zathura
        ];
    };
}
