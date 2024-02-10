{
    programs.nixvim.plugins = {
        treesitter = {
            enable = true;

            ensureInstalled = "all";

            folding = true;
            indent = true;

            incrementalSelection = {
                enable = true;
                keymaps = {
                    initSelection = "<c-space>";
                    nodeIncremental = "<c-space>";
                    nodeDecremental = "<c-backspace>";
                    scopeIncremental = "<c-s>";
                };
            };
        };
        treesitter-context.enable = true;
    };
}
