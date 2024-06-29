{
  programs.nixvim = {
    plugins = {
      neogit = {
        enable = true;
        settings = {
          kind = "floating";
          commit_editor = {
            kind = "floating";
            show_staged_diff = false;
          };
          commit_select_view.kind = "floating";
          commit_view.kind = "floating";
          log_view.kind = "floating";
          rebase_editor.kind = "floating";
          reflog_view.kind = "floating";
          merge_editor.kind = "floating";
          tag_editor.kind = "floating";
          preview_buffer.kind = "floating";
          popup.kind = "floating";
          description_editor.kind = "floating";
        };
      };
    };
    keymaps = [
      {
        mode = "n";
        key = "<leader>gg";
        action = "<cmd>Neogit<cr>";
        options.desc = "Open neogit";
      }
    ];
  };
}
