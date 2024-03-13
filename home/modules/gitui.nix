{
  pkgs,
  config,
  lib,
  nix-colors,
  ...
}: {
  programs.gitui = {
    enable = true;
    theme = ''
      (
          selected_tab: Reset,
          command_fg: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base05}),
          selection_bg: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base04}),
          selection_fg: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base05}),
          cmdbar_bg: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base01}),
          cmdbar_extra_lines_bg: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base01}),
          disabled_fg: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base04}),
          diff_line_add: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base0B}),
          diff_line_delete: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base08}),
          diff_file_added: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base0A}),
          diff_file_removed: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base08}),
          diff_file_moved: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base0E}),
          diff_file_modified: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base09}),
          commit_hash: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base07}),
          commit_time: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base05}),
          commit_author: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base0D}),
          danger_fg: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base08}),
          push_gauge_bg: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base0D}),
          push_gauge_fg: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base00}),
          tag_fg: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base0E}),
          branch_fg: Rgb(${nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base0C})
      )
    '';
  };

  home.shellAliases = {
    gi = "gitui";
  };
}
