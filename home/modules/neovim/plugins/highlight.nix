{
  programs.nixvim = {
    autoGroups = {
      Highlight = {
        clear = true;
      };
    };
    autoCmd = [
      {
        group = "Highlight";
        event = ["TextYankPost"];
        callback = {__raw = "function() vim.highlight.on_yank() end";};
        desc = "Highlight yanked text";
      }
    ];
  };
}
