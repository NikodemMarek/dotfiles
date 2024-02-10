{
    programs.nixvim = {
        plugins = {
            cursorline = {
                enable = true;

                cursorline.number = true;
                cursorline.timeout = 0;

                cursorword.enable = true;
            };
         };
    };
}
