{
  programs.nixvim = {
    plugins.oil = {
      enable = true;
      defaultFileExplorer = true;

      settings = {
        columns = ["icon" "permissions" "size"];
        experimental_watch_for_changes = true;
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
