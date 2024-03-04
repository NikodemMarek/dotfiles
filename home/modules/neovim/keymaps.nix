{
  programs.nixvim.keymaps = [
    # Write actions
    {
      mode = "n";
      key = "<leader>ff";
      action = "<cmd>w<cr>";
      options.desc = "Write";
    }
    {
      mode = "n";
      key = "<leader>fa";
      action = "<cmd>wa<cr>";
      options.desc = "Write all";
    }

    # Quit actions
    {
      mode = "n";
      key = "<leader>qq";
      action = "<cmd>q<cr>";
      options.desc = "Quit";
    }
    {
      mode = "n";
      key = "<leader>qa";
      action = "<cmd>qa!<cr>";
      options.desc = "Quit all";
    }

    # Navigate windows
    {
      mode = "n";
      key = "<c-h>";
      action = "<c-w><c-h>";
      options.desc = "Navigate windows to the left";
    }
    {
      mode = "n";
      key = "<c-j>";
      action = "<c-w><c-j>";
      options.desc = "Navigate windows down";
    }
    {
      mode = "n";
      key = "<c-k>";
      action = "<c-w><c-k>";
      options.desc = "Navigate windows up";
    }
    {
      mode = "n";
      key = "<c-l>";
      action = "<c-w><c-l>";
      options.desc = "Navigate windows to the right";
    }

    # Move windows
    {
      mode = "n";
      key = "<s-left>";
      action = "<c-w><s-h>";
      options.desc = "Move window to the left";
    }
    {
      mode = "n";
      key = "<s-down>";
      action = "<c-w><s-j>";
      options.desc = "Move window down";
    }
    {
      mode = "n";
      key = "<s-up>";
      action = "<c-w><s-k>";
      options.desc = "Move window up";
    }
    {
      mode = "n";
      key = "<s-right>";
      action = "<c-w><s-l>";
      options.desc = "Move window to the right";
    }

    # Resize windows
    {
      mode = "n";
      key = "<c-up>";
      action = "<cmd>resize +2<cr>";
    }
    {
      mode = "n";
      key = "<c-down>";
      action = "<cmd>resize -2<cr>";
    }
    {
      mode = "n";
      key = "<c-left>";
      action = "<cmd>vertical resize +2<cr>";
    }
    {
      mode = "n";
      key = "<c-right>";
      action = "<cmd>vertical resize -2<cr>";
    }

    # Close window
    {
      mode = "n";
      key = "<leader>dw";
      action = "<cmd>close<cr>";
      options.desc = "Window";
    }
    # Delete buffer
    {
      mode = "n";
      key = "<leader>dd";
      action = "<cmd>bdelete<cr>";
      options.desc = "Buffer";
    }

    # Navigate buffers
    {
      mode = "n";
      key = "<s-l>";
      action = "<cmd>bnext<cr>";
      options.desc = "Next buffer";
    }
    {
      mode = "n";
      key = "<s-h>";
      action = "<cmd>bprevious<cr>";
      options.desc = "Previous buffer";
    }

    # Indent
    {
      mode = "v";
      key = "<";
      action = "<gv";
      options.desc = "Indent right";
    }
    {
      mode = "v";
      key = ">";
      action = ">gv";
      options.desc = "Indent left";
    }

    # Clear search highlights
    {
      mode = "n";
      key = "<leader>ur";
      action = "<cmd>nohl<cr>";
      options.desc = "Clear highlights";
    }

    # Exit terminal mode
    {
      mode = "t";
      key = "<esc>";
      action = "<c-\\><c-n>";
      options.desc = "Exit terminal mode";
    }
  ];
}
