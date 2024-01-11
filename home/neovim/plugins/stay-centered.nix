{
    programs.nixvim = {
        extraConfigLua = ''
            local mode = {
                insert = "insert",
                other = "other",
            }

            local function must_skip_file(skip_filetypes, current_type)
                if skip_filetypes == nil then
                    return false
                end

                for _, value in ipairs(skip_filetypes) do
                    if value == current_type then
                        return true
                    end
                end

                return false
            end

            local function stay_centered(ctx)
                if must_skip_file(ctx.skip_filetypes, vim.bo.filetype) then
                    return
                end

                local line = vim.api.nvim_win_get_cursor(0)[1]
                if line ~= vim.b.last_line then
                    vim.cmd("norm! zz")
                    vim.b.last_line = line
                    if ctx.mode == mode.insert then
                        local column = vim.fn.getcurpos()[5]
                        vim.fn.cursor({ line, column })
                    end
                end
            end

            local skip_filetypes = {}
        '';
        autoGroups = {
            StayCentered = {
                clear = true;
            };
        };
        autoCmd = [
           {
               group = "StayCentered";
               event = [ "CursorMovedI" ];
               callback = { __raw = "function() stay_centered({ mode = mode.insert, skip_filetypes = skip_filetypes }) end"; };
               desc = "Center cursor on movement action in insert mode";
           }
           {
               group = "StayCentered";
               event = [ "CursorMoved" ];
               callback = { __raw = "function() stay_centered({ mode = mode.other, skip_filetypes = skip_filetypes }) end"; };
               desc = "Center cursor on movement action";
           }
           {
               group = "StayCentered";
               event = [ "BufEnter" ];
               callback = { __raw = "function() stay_centered({ mode = mode.other, skip_filetypes = skip_filetypes }) end"; };
               desc = "Center cursor when entering buffer";
           }
       ];
    };
}
