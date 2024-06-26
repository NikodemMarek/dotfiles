{
  programs.nixvim = {
    plugins.toggleterm = {
      enable = true;
      settings = {
        direction = "vertical";
        size = ''
          function(term)
            if term.direction == "horizontal" then
              return 15
            elseif term.direction == "vertical" then
              return vim.o.columns * 0.35
            end
          end
        '';
      };
    };
    keymaps = [
      {
        mode = "n";
        key = "<leader>tt";
        action = "<cmd>ToggleTerm<cr>";
        options.desc = "Toggle terminal";
      }
      {
        mode = "n";
        key = "<leader>ts";
        action = "<cmd>TermSelect<cr>";
        options.desc = "Select terminal";
      }
      {
        mode = "n";
        key = "<leader>tr";
        action.__raw = ''
          function()
              local command = vim.ui.input("cmd: ", "", "shellcmd")
              if command == "" then
                  return
              end

              vim.cmd("TermExec cmd='" .. command .. "'")
          end
        '';
        options.desc = "Run in terminal";
      }
    ];
  };
}
