{
  programs.nixvim = {
    extraConfigLua = ''
      function waitforedit(path)
        vim.fn.jobstart("${../scripts/waitforedit} " .. path, {
          on_stdout = function(_, res, _)
            vim.cmd("checktime " .. path)
          end
        })
      end
    '';
    autoGroups = {
      Autoread = {
        clear = true;
      };
    };
    autoCmd = [
      {
        group = "Autoread";
        event = ["FocusGained" "BufEnter"];
        command = "checktime";
        desc = "Reload file on focus";
      }
      {
        group = "Autoread";
        event = ["BufWritePost" "BufAdd"];
        callback = {__raw = "function() waitforedit(vim.api.nvim_buf_get_name(0)) end";};
        desc = "Reload file on inotify event";
      }
    ];
  };
}
