{ pkgs, ... }: {
  programs.nixvim = {
    plugins.oil = {
      enable = true;
      defaultFileExplorer = true;

      columns.icon.enable = true;
      columns.permissions.enable = true;
      columns.size.enable = true;
    };
    keymaps = [
      { mode = "n"; key = "<leader>e"; action = "<cmd>Oil<cr>"; options.desc = "Open file explorer"; }
    ];
  };
}
