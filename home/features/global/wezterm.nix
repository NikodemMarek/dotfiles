{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./fish.nix
  ];

  programs.wezterm = {
    enable = true;
    package = inputs.wezterm.packages.${pkgs.system}.default;
    extraConfig =
      /*
      lua
      */
      ''
        local ssh_domains = {}
        for host, config in pairs(wezterm.enumerate_ssh_hosts()) do
          table.insert(ssh_domains, {
            name = host,
            remote_address = host,
            assume_shell = 'Posix',
          })
        end

        return {
            enable_wayland = false,
            window_close_confirmation = "NeverPrompt",

            unix_domains = {
                {
                    name = 'unix',
                },
            },
            default_gui_startup_args = { 'connect', 'unix' },

            ssh_domains = ssh_domains,

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
