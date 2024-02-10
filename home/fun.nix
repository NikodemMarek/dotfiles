{
    settings = {
        eww = {
          shortcuts = [
            [
                [ "firefox" "" ]
                [ "qutebrowser" "󰖟" ]
                [ "steam" "st" ]
            ]
            [
                [ "lutris" "lt" ]
                [ "beeper --default-frame" "󰵅" ]
                [ "prismlauncher" "mc" ]
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

            ./modules/tools.nix
            ./modules/firefox.nix
            ./modules/qutebrowser.nix
        ];

        home.packages = with pkgs; [
            rnote
            beeper
            zathura
        ];
    };
}
