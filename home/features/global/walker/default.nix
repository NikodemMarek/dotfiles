{
  inputs,
  lib,
  config,
  ...
}: {
  imports = [
    inputs.walker.homeManagerModules.default
  ];

  programs.walker = {
    enable = true;
    runAsService = true;
    config = {
      theme = "catppuccin";
      terminal = "${lib.getExe config.programs.wezterm.package} start";
      show_initial_entries = true;
      list = {
        height = 500;
      };
      icons = {
        hide = false;
        size = 28;
      };
      modules = [
        {
          name = "runner";
          "prefix" = "";
        }
        {
          name = "applications";
          "prefix" = "";
        }
        {
          name = "ssh";
          prefix = "";
          switcher_exclusive = true;
        }
        {
          name = "finder";
          prefix = "";
          switcher_exclusive = true;
        }
        {
          name = "commands";
          prefix = "";
          switcher_exclusive = true;
        }
        {
          name = "websearch";
          prefix = "?";
        }
        {
          name = "switcher";
          prefix = "/";
        }
      ];
    };
  };
}
