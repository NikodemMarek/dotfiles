{
    programs.nixvim = {
        plugins = {
            gitsigns = {
                enable = true;
                currentLineBlame = true;
            };
        };
    };
}
