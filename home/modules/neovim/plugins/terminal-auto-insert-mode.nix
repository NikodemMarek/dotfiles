{
    programs.nixvim = {
        autoCmd = [
            {
                event = [ "TermOpen" "BufEnter" ];
                pattern = [ "*" ];
                command = "if &buftype == 'terminal' | :startinsert | endif";
                desc = "Enter insert mode when entering terminal buffer";
            }
       ];
    };
}
