{
  programs.nixvim = {
    plugins.toggleterm = {
      enable = true;
      settings = {
        direction = "float";
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
