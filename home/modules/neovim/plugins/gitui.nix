{
  programs.nixvim = {
    keymaps = [
      {
        mode = "n";
        key = "<leader>ug";
        action = "<cmd>TermExec direction=tab cmd='gitui'<cr>";
        options.desc = "Open gitui";
      }
    ];
  };
}
