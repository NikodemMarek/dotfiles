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

            unix_domains = {
                {
                    name = 'unix',
                },
            },
            default_gui_startup_args = { 'connect', 'unix' },

            ssh_domains = {
                {
                    name = 'desktop.nikodem',
                    remote_address = 'desktop.nikodem',
                    username = 'nikodem',
                },
                {
                    name = 'laptop.nikodem',
                    remote_address = 'laptop.nikodem',
                    username = 'nikodem',
                },
                {
                    name = 'LP-043.nm1',
                    remote_address = 'LP-043.nm1',
                    username = 'nm1',
                },
            },

            keys = {
                {
                    key = 'x',
                    mods = 'ALT',
                    action = wezterm.action.ActivateCopyMode,
                },
                {
                    key = 'Space',
                    mods = 'ALT',
                    action = wezterm.action.QuickSelect,
                },
                {
                    key = 'f',
                    mods = 'ALT',
                    action = wezterm.action.Search("CurrentSelectionOrEmptyString"),
                },
                {
                    key = 'p',
                    mods = 'ALT',
                    action = wezterm.action.ActivateCommandPalette,
                },

                {
                    key = 's',
                    mods = 'ALT',
                    action = wezterm.action.PaneSelect,
                },
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
                    key = 'z',
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
