{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        name = "trailblazer";
        src = pkgs.fetchFromGitHub {
          owner = "LeonHeidelbach";
          repo = "trailblazer.nvim";
          rev = "main";
          hash = "sha256-9q8CmbUGmbKb7w4fzOS7XBSg8YM5WwqwvLUN2pVOAtI=";
        };
      })
    ];
    extraConfigLua = ''
      require('trailblazer').setup({
          mappings = {
              nv = {
                  motions = {
                      new_trail_mark = '<A-l>',
                      track_back = '<A-b>',
                      peek_move_next_down = '<S-h>',
                      peek_move_previous_up = '<S-l>',
                      move_to_nearest = '<A-n>',
                      toggle_trail_mark_list = '<A-m>',
                  },
                  actions = {
                      delete_all_trail_marks = '<A-L>',
                      paste_at_last_trail_mark = '<A-p>',
                      paste_at_all_trail_marks = '<A-P>',
                      set_trail_mark_select_mode = '<A-t>',
                      switch_to_next_trail_mark_stack = '<A-k>',
                      switch_to_previous_trail_mark_stack = '<A-j>',
                      set_trail_mark_stack_sort_mode = '<A-s>',
                  },
              },
          },
      })
    '';
  };
}
