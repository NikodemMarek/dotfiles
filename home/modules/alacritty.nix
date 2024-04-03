{config, ...}: {
  imports = [
    ./shell.nix
  ];

  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";
      window.padding = {
        x = 5;
        y = 5;
      };
      cursor = {
        style = "Block";
        unfocused_hollow = true;
      };
      colors = {
        indexed_colors = [
          {
            color = "#${config.colorScheme.palette.base09}";
            index = 16;
          }
          {
            color = "#${config.colorScheme.palette.base06}";
            index = 17;
          }
        ];
        bright = {
          black = "#${config.colorScheme.palette.base04}";
          blue = "#${config.colorScheme.palette.base0D}";
          cyan = "#${config.colorScheme.palette.base0C}";
          green = "#${config.colorScheme.palette.base0B}";
          magenta = "#${config.colorScheme.palette.base0F}";
          red = "#${config.colorScheme.palette.base08}";
          white = "#${config.colorScheme.palette.base07}";
          yellow = "#${config.colorScheme.palette.base0A}";
        };
        cursor = {
          cursor = "#${config.colorScheme.palette.base06}";
          text = "#${config.colorScheme.palette.base00}";
        };
        dim = {
          black = "#${config.colorScheme.palette.base03}";
          blue = "#${config.colorScheme.palette.base0D}";
          cyan = "#${config.colorScheme.palette.base0C}";
          green = "#${config.colorScheme.palette.base0B}";
          magenta = "#${config.colorScheme.palette.base0F}";
          red = "#${config.colorScheme.palette.base08}";
          white = "#${config.colorScheme.palette.base05}";
          yellow = "#${config.colorScheme.palette.base0A}";
        };
        footer_bar = {
          background = "#${config.colorScheme.palette.base07}";
          foreground = "#${config.colorScheme.palette.base00}";
        };
        hints = {
          end = {
            background = "#${config.colorScheme.palette.base07}";
            foreground = "#${config.colorScheme.palette.base00}";
          };
          start = {
            background = "#${config.colorScheme.palette.base0A}";
            foreground = "#${config.colorScheme.palette.base00}";
          };
        };
        normal = {
          black = "#${config.colorScheme.palette.base03}";
          blue = "#${config.colorScheme.palette.base0D}";
          cyan = "#${config.colorScheme.palette.base0C}";
          green = "#${config.colorScheme.palette.base0B}";
          magenta = "#${config.colorScheme.palette.base0F}";
          red = "#${config.colorScheme.palette.base08}";
          white = "#${config.colorScheme.palette.base05}";
          yellow = "#${config.colorScheme.palette.base0A}";
        };
        primary = {
          background = "#${config.colorScheme.palette.base00}";
          bright_foreground = "#${config.colorScheme.palette.base05}";
          dim_foreground = "#${config.colorScheme.palette.base05}";
          foreground = "#${config.colorScheme.palette.base05}";
        };
        search = {
          focused_match = {
            background = "#${config.colorScheme.palette.base0B}";
            foreground = "#${config.colorScheme.palette.base00}";
          };
          matches = {
            background = "#${config.colorScheme.palette.base07}";
            foreground = "#${config.colorScheme.palette.base00}";
          };
        };
        selection = {
          background = "#${config.colorScheme.palette.base06}";
          text = "#${config.colorScheme.palette.base00}";
        };
        vi_mode_cursor = {
          cursor = "#${config.colorScheme.palette.base07}";
          text = "#${config.colorScheme.palette.base00}";
        };
      };
    };
  };
}
