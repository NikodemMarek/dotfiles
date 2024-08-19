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
    extraConfig =
      /*
      lua
      */
      ''
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
                    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
                },
                {
                    key = 'w',
                    mods = 'ALT',
                    action = wezterm.action.CloseCurrentTab { confirm = false },
                },

                {
                    key = 'v',
                    mods = 'ALT',
                    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
                },
                {
                    key = 's',
                    mods = 'ALT',
                    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
                },

                {
                    key = 'l',
                    mods = 'ALT',
                    action = wezterm.action.ActivatePaneDirection 'Right',
                },
                {
                    key = 'h',
                    mods = 'ALT',
                    action = wezterm.action.ActivatePaneDirection 'Left',
                },
                {
                    key = 'j',
                    mods = 'ALT',
                    action = wezterm.action.ActivatePaneDirection 'Down',
                },
                {
                    key = 'k',
                    mods = 'ALT',
                    action = wezterm.action.ActivatePaneDirection 'Up',
                },

                {
                    key = 'd',
                    mods = 'ALT',
                    action = wezterm.action.CloseCurrentPane { confirm = true },
                },
            },
        }
      '';
  };
}
