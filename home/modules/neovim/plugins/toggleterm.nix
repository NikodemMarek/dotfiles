{
    programs.nixvim = {
        plugins.toggleterm = {
            enable = true;
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
        keymaps = [
            { mode = "n"; key = "<leader>tt"; action = "<cmd>ToggleTerm<cr>"; options.desc = "Toggle terminal"; }
            { mode = "n"; key = "<leader>ts"; action = "<cmd>TermSelect<cr>"; options.desc = "Select terminal"; }
            {
                mode = "n";
                key = "<leader>tr";
                action = ''
                    function()
                        local command = vim.fn.input("cmd: ", "", "shellcmd")
                        if command == "" then
                            return
                        end

                        vim.cmd("TermExec cmd='" .. command .. "'")
                    end
                '';
                lua = true;
                options.desc = "Run in terminal";
            }
        ];
    };
}
