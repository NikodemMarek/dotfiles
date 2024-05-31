{config, ...}: {
  imports = [
    ./powermodule.nix
  ];

  programs.walker = {
    enable = true;
    config = {
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

    style = ''
      * {
        color: #${config.stylix.base16Scheme.base00};
      }

      #window {
      }

      #box {
        background: #${config.stylix.base16Scheme.base00};
        padding: 10px;
        border-radius: 2px;
      }

      #searchwrapper {
      }

      #search,
      #typeahead {
        border-radius: 0;
        outline: none;
        outline-width: 0px;
        box-shadow: none;
        border-bottom: none;
        border: none;
        background: #${config.stylix.base16Scheme.base02};
        padding-left: 10px;
        padding-right: 10px;
        padding-top: 0px;
        padding-bottom: 0px;
        border-radius: 2px;
      }

      #spinner {
        opacity: 0;
      }

      #spinner.visible {
        opacity: 1;
      }

      #typeahead {
        background: none;
        opacity: 0.5;
      }

      #search placeholder {
        opacity: 0.5;
      }

      #list {
      }

      row:selected {
        background: #${config.stylix.base16Scheme.base02};
      }

      .item {
        padding: 5px;
        border-radius: 2px;
      }

      .icon {
        padding-right: 5px;
      }

      .textwrapper {
      }

      .label {
      }

      .sub {
        opacity: 0.5;
      }

      .activationlabel {
        opacity: 0.25;
      }

      .activation .activationlabel {
        opacity: 1;
        color: #${config.stylix.base16Scheme.base00};
      }

      .activation .textwrapper,
      .activation .icon,
      .activation .search {
        opacity: 0.5;
      }
    '';
  };
}
