{
  programs.nixvim = {
    plugins = {
      cmp = {
        enable = true;
        settings = {
          mapping = {
            "<C-space>" = "cmp.mapping.complete()";
            "<C-d>" = "cmp.mapping.scroll_docs(-4)";
            "<C-f>" = "cmp.mapping.scroll_docs(4)";
            "<C-E>" = "cmp.mapping.close()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<S-tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
            "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
          };
          sources = [
            {name = "nvim_lsp";}
            {name = "copilot";}
            {name = "luasnip";}
            {name = "buffer";}
            {name = "path";}
            {name = "spell";}
          ];
          formatting.fields = ["kind" "abbr" "menu"];
          snippet.expand = "luasnip";
          experimental = {
            ghost_text = true;
          };
        };
      };
      cmp-nvim-lsp.enable = true;
      cmp-buffer.enable = true;
      cmp-path.enable = true;
      cmp-nvim-lsp-signature-help.enable = true;
      cmp-spell.enable = true;
      lspkind = {
        enable = true;
        cmp.enable = true;
      };
    };
  };
}
