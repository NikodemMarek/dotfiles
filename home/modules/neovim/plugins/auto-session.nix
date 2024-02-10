{
    programs.nixvim = {
        plugins = {
            auto-session = {
                enable = true;
                autoRestore.enabled = true;
                autoSave.enabled = true;
            };
        };
        keymaps = [
            { mode = "n"; key = "<leader>qd"; action = "<cmd>SessionDelete<cr><cmd>qa!<cr>"; options.desc = "Delete session and quit all"; }
            { mode = "n"; key = "<leader>us"; action = "<cmd>SessionDelete<cr>"; options.desc = "Delete session"; }
        ];
    };
}
