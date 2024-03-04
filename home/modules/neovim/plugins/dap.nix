{
  programs.nixvim = {
    plugins = {
      dap = {
        enable = true;
        extensions.dap-ui = {
          enable = true;
          layouts = [
            {
              elements = [
                {
                  id = "scopes";
                  size = 0.25;
                }
                {
                  id = "breakpoints";
                  size = 0.25;
                }
                {
                  id = "stacks";
                  size = 0.25;
                }
                {
                  id = "watches";
                  size = 0.25;
                }
              ];
              position = "left";
              size = 40;
            }
            {
              elements = [
                {
                  id = "repl";
                  size = 0.5;
                }
                {
                  id = "console";
                  size = 0.5;
                }
              ];
              position = "bottom";
              size = 10;
            }
          ];
        };
      };
    };
    keymaps = [
      # Toggle dap ui
      {
        mode = "n";
        key = "<leader>ub";
        action = "<cmd>lua require('dapui').toggle()<cr>";
        options.desc = "Toggle ui";
      }

      {
        mode = "n";
        key = "<leader>bb";
        action = "<cmd>DapToggleBreakpoint<cr>";
        options.desc = "Toggle breakpoint";
      }

      {
        mode = "n";
        key = "<leader>bi";
        action = "<cmd>DapStepInto<cr>";
        options.desc = "Step into";
      }
      {
        mode = "n";
        key = "<leader>bo";
        action = "<cmd>DapStepOut<cr>";
        options.desc = "Step out";
      }
      {
        mode = "n";
        key = "<leader>bv";
        action = "<cmd>DapStepOver<cr>";
        options.desc = "Step over";
      }

      {
        mode = "n";
        key = "<leader>bc";
        action = "<cmd>DapContinue<cr>";
        options.desc = "Continue";
      }
      {
        mode = "n";
        key = "<leader>bd";
        action = "<cmd>DapTerminate<cr>";
        options.desc = "Terminate";
      }
    ];
  };
}
