{
  programs.nixvim = {
    plugins.oil = {
      enable = true;
      settings = {
        default_file_explorer = true;
        columns = ["icon" "permissions" "size"];
        experimental_watch_for_changes = true;
        skip_confirm_for_simple_edits = true;
        keymaps = {
          "<C-h>" = false;
          "<C-l>" = false;
          "`" = false;
          "~" = false;
          "g\\" = false;
        };
      };
    };
    keymaps = [
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Oil<cr>";
        options.desc = "Open file explorer";
      }
    ];
  };
}
