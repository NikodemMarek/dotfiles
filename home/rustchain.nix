{
    settings = {
        name = "nikodem";
        email = "nikodemmarekit@gmail.com";
        eww = {
            shortcuts = [
                [
                    [ "firefox" "" ]
                    [ "qutebrowser" "󰖟" ]
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
            patchelf
            beeper
            zathura
            yarn
            bun
            gcc
            solana-platform-tools
            solana-cli
            anchor-cli
        ];
    };
}
