{
    programs.nixvim = {
        plugins = {
            nvim-cmp = {
                enable = true;
                mapping = {
                  "<c-space>" = "cmp.mapping.complete()";
                  "<c-d>" = "cmp.mapping.scroll_docs(-4)";
                  "<c-f>" = "cmp.mapping.scroll_docs(4)";
                  "<c-e>" = "cmp.mapping.close()";
                  "<cr>" = "cmp.mapping.confirm({ select = true })";
                  "<s-tab>" = {
                    action = "cmp.mapping.select_prev_item()";
                    modes = [ "i" "s" ];
                  };
                  "<Tab>" = {
                    action = "cmp.mapping.select_next_item()";
                    modes = [ "i" "s" ];
                  };
                };
                sources = [
                    { name = "nvim_lsp"; }
                    { name = "copilot"; }
                    { name = "luasnip"; }
                    { name = "buffer"; }
                    { name = "path"; }
                    { name = "spell"; }
                ];
                formatting.fields = [ "kind" "abbr" "menu" ];
                snippet.expand = "luasnip";
                experimental = {
                    ghost_text = true;
                };
            };
            cmp-nvim-lsp.enable = true;
            cmp-buffer.enable = true;
            cmp-path.enable = true;
            cmp-nvim-lsp-signature-help.enable = true;
            cmp-spell.enable = true;
        };
    };
}
