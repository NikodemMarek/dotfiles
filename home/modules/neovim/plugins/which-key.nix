{
    programs.nixvim = {
        plugins = {
            which-key = {
                enable = true;

                registrations = {
                    "<leader>f" = "File";
                    "<leader>d" = "Close";
                    "<leader>q" = "Quit";
                    "<leader>s" = "Search";
                    "<leader>l" = "LSP";
                    "<leader>u" = "UI";
                    "<leader>b" = "Debugging";
                };
            };
        };
    };
}
