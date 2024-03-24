{
  settings = {
    name = "nikodem";
    email = "nikodemmarekit@gmail.com";
    eww = {
      shortcuts = [
        [
          ["firefox" ""]
          ["qutebrowser" "󰖟"]
        ]
      ];
    };
  };

  module = {
    inputs,
    outputs,
    lib,
    config,
    pkgs,
    settings,
    ...
  }: {
    imports =
      [
        ./modules/neovim
        ./modules/hyprland
        ./modules/eww

        ./modules/git.nix
        ./modules/gh.nix
        ./modules/tools.nix
        ./modules/firefox.nix
        ./modules/qutebrowser.nix
      ]
      ++ (
        if settings.device == "laptop"
        then [./modules/battery-notifier.nix]
        else []
      );

    home.packages = with pkgs; [
      patchelf
      beeper
      zathura
      yarn
      bun
      gcc
      solana-cli
      solana-platform-tools
      anchor-cli
    ];
  };
}
