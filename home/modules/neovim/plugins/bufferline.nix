{
    programs.nixvim = {
        plugins = {
            bufferline = {
                enable = true;
                alwaysShowBufferline = false;
                showBufferCloseIcons = false;
                diagnostics = true;
            };
        };
    };
}
