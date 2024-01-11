{
    programs.nixvim = {
        plugins = {
            mini = {
                enable = true;
                modules = {
                    surround = {};
                    trailspace = {};
                    splitjoin = {};
                    pairs = {};
                    move = {
                        mappings = {
                            left = "<a-left>";
                            right = "<a-right>";
                            down = "<a-down>";
                            up = "<a-up>";

                            line_left = "<a-left>";
                            line_right = "<a-right>";
                            line_down = "<a-down>";
                            line_up = "<a-up>";
                        };
                    };
                };
            };
        };
    };
}
