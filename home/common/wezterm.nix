{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./shell.nix
  ];

  programs.wezterm = {
    enable = true;
    package = inputs.wezterm.packages.${pkgs.system}.default;
    extraConfig= ''
    return {
        enable_wayland = false,
        window_close_confirmation = "NeverPrompt",

        keys = {
            {
                key = 'Tab',
                mods = 'ALT',
                action = wezterm.action.ActivateTabRelative(1),
            },
            {
                key = 'Tab',
                mods = 'ALT|SHIFT',
                action = wezterm.action.ActivateTabRelative(-1),
            },
            {
                key = 'Enter',
                mods = 'ALT',
                action = wezterm.action.SpawnTab('CurrentPaneDomain'),
            },
        },
    }
    '';
  };
}
