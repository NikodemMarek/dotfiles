{ config, pkgs, lib, email, name, ... }: {
  extraPkgs = [
    "bat"
    "mpv"
    "feh"
  ];

  module = { config, ... }: {
    programs.joshuto = {
      enable = true;
      settings = {
        scroll_offset = 6;
        xdg_open = false;
        xdg_open_fork = false;
        use_trash = true;
        watch_files = true;
        display = {
          mode = "default";
          collapse_preview = false;
          column_ratio = [ 0 3 4 ];
          show_borders = false;
          show_hidden = false;
          show_icons = true;
          tilde_in_titlebar = true;
          line_number_style = "relative";
          sort = {
            method = "natural";
            case_sensitive = false;
            directories_first = true;
            reverse = false;
          };
        };
        preview = {
          preview_script = "${config.home.homeDirectory}/${config.xdg.configFile."joshuto/file_preview.sh".target}";
        };
      };
      mimetype = {
        class = {
          text_default = [
            { command = "bat"; fork = false; silent = true; }
            { command = "nvim"; fork = false; silent = true; }
          ];
          image_default = [
            { command = "feh"; fork = true; silent = true; }
          ];
          audio_default = [
            { command = "mpv"; args = [ "--no-video" ]; fork = false; silent = false; }
          ];
          video_default = [
            { command = "mpv"; args = [ "--" ]; fork = true; silent = true; }
          ];
        };
        extension = {
          # image formats
          avif."inherit" = "image_default";
          bmp."inherit" = "image_default";
          gif."inherit" = "image_default";
          heic."inherit" = "image_default";
          jpeg."inherit" = "image_default";
          jpe."inherit" = "image_default";
          jpg."inherit" = "image_default";
          pgm."inherit" = "image_default";
          png."inherit" = "image_default";
          ppm."inherit" = "image_default";
          webp."inherit" = "image_default";

          svg.app_list = [{ command = "inkscape"; fork = true; silent = true; }];

          ## audio formats
          flac."inherit" = "audio_default";
          m4a."inherit" = "audio_default";
          mp3."inherit" = "audio_default";
          ogg."inherit" = "audio_default";
          wav."inherit" = "audio_default";

          ## video formats
          avi."inherit" = "video_default";
          av1."inherit" = "video_default";
          flv."inherit" = "video_default";
          mkv."inherit" = "video_default";
          m4v."inherit" = "video_default";
          mov."inherit" = "video_default";
          mp4."inherit" = "video_default";
          ts."inherit" = "video_default";
          webm."inherit" = "video_default";
          wmv."inherit" = "video_default";

          ## text formats
          build."inherit" = "text_default";
          c."inherit" = "text_default";
          cmake."inherit" = "text_default";
          conf."inherit" = "text_default";
          cpp."inherit" = "text_default";
          css."inherit" = "text_default";
          csv."inherit" = "text_default";
          cu."inherit" = "text_default";
          ebuild."inherit" = "text_default";
          eex."inherit" = "text_default";
          env."inherit" = "text_default";
          ex."inherit" = "text_default";
          exs."inherit" = "text_default";
          go."inherit" = "text_default";
          h."inherit" = "text_default";
          hpp."inherit" = "text_default";
          hs."inherit" = "text_default";
          html."inherit" = "text_default";
          ini."inherit" = "text_default";
          java."inherit" = "text_default";
          js."inherit" = "text_default";
          json."inherit" = "text_default";
          kt."inherit" = "text_default";
          lua."inherit" = "text_default";
          log."inherit" = "text_default";
          md."inherit" = "text_default";
          micro."inherit" = "text_default";
          ninja."inherit" = "text_default";
          py."inherit" = "text_default";
          rkt."inherit" = "text_default";
          rs."inherit" = "text_default";
          scss."inherit" = "text_default";
          sh."inherit" = "text_default";
          srt."inherit" = "text_default";
          svelte."inherit" = "text_default";
          toml."inherit" = "text_default";
          tsx."inherit" = "text_default";
          txt."inherit" = "text_default";
          vim."inherit" = "text_default";
          xml."inherit" = "text_default";
          yaml."inherit" = "text_default";
          yml."inherit" = "text_default";
        };
        mimetype = {
          # text/*
          text."inherit" = "text_default";
          video."inherit" = "video_default";
          # application/octet-stream
          application.subtype.octet-stream."inherit" = "video_default";
        };
      };
      theme = {
        tabs = {
          inactive = { };
          active.invert = true;
        };
        selection = {
          fg = "rgb(245, 224, 220)";
          bold = true;
          prefix = {
            prefix = "  ";
            size = 2;
          };
        };
        visual_mode_selection = {
          fg = "rgb(250, 179, 135)";
          bold = true;
        };
        regular.fg = "rgb(205, 214, 244)";
        directory = {
          fg = "rgb(203, 166, 247)";
          bold = true;
        };
        link = {
          fg = "rgb(148, 226, 213)";
          bold = true;
        };
        link_invalid = {
          fg = "rgb(137, 220, 235)";
          bold = true;
        };
        socket = {
          fg = "rgb(235, 160, 172)";
          bold = true;
        };
        executable = {
          fg = "rgb(166, 227, 161)";
          bold = true;
        };
        ext = {
          bmp.fg = "rgb(249, 226, 175)";
          gif.fg = "rgb(249, 226, 175)";
          heic.fg = "rgb(249, 226, 175)";
          jpg.fg = "rgb(249, 226, 175)";
          jpeg.fg = "rgb(249, 226, 175)";
          pgm.fg = "rgb(249, 226, 175)";
          png.fg = "rgb(249, 226, 175)";
          ppm.fg = "rgb(249, 226, 175)";
          svg.fg = "rgb(249, 226, 175)";
          wav.fg = "rgb(180, 190, 254)";
          flac.fg = "rgb(180, 190, 254)";
          mp3.fg = "rgb(180, 190, 254)";
          amr.fg = "rgb(180, 190, 254)";
          avi.fg = "rgb(180, 190, 254)";
          flv.fg = "rgb(180, 190, 254)";
          m3u.fg = "rgb(180, 190, 254)";
          m4a.fg = "rgb(180, 190, 254)";
          m4v.fg = "rgb(180, 190, 254)";
          mkv.fg = "rgb(180, 190, 254)";
          mov.fg = "rgb(180, 190, 254)";
          mp4.fg = "rgb(180, 190, 254)";
          mpg.fg = "rgb(180, 190, 254)";
          rmvb.fg = "rgb(180, 190, 254)";
          webm.fg = "rgb(180, 190, 254)";
          wmv.fg = "rgb(180, 190, 254)";
          "7z".fg = "rgb(116, 199, 236)";
          bz2.fg = "rgb(116, 199, 236)";
          gz.fg = "rgb(116, 199, 236)";
          rar.fg = "rgb(116, 199, 236)";
          tar.fg = "rgb(116, 199, 236)";
          tgz.fg = "rgb(116, 199, 236)";
          xz.fg = "rgb(116, 199, 236)";
          zip.fg = "rgb(116, 199, 236)";
        };
      };
      keymap = {
        default_view = {
          keymap = [
            { keys = [ "escape" ]; commands = [ "escape" ]; }
            { keys = [ "ctrl+t" ]; commands = [ "new_tab" ]; }
            { keys = [ "alt+t" ]; commands = [ "new_tab --cursor" ]; }
            { keys = [ "T" ]; commands = [ "new_tab --current" ]; }
            { keys = [ "W" ]; commands = [ "close_tab" ]; }
            { keys = [ "ctrl+w" ]; commands = [ "close_tab" ]; }
            { keys = [ "q" ]; commands = [ "close_tab" ]; }
            { keys = [ "ctrl+c" ]; commands = [ "quit" ]; }
            { keys = [ "Q" ]; commands = [ "quit --output-current-directory" ]; }
            { keys = [ "ctrl+r" ]; commands = [ "reload_dirlist" ]; }
            { keys = [ "z" "h" ]; commands = [ "toggle_hidden" ]; }
            { keys = [ "ctrl+h" ]; commands = [ "toggle_hidden" ]; }
            { keys = [ "\t" ]; commands = [ "tab_switch 1" ]; }
            { keys = [ "backtab" ]; commands = [ "tab_switch -1" ]; }
            { keys = [ "alt+1" ]; commands = [ "tab_switch_index 1" ]; }
            { keys = [ "alt+2" ]; commands = [ "tab_switch_index 2" ]; }
            { keys = [ "alt+3" ]; commands = [ "tab_switch_index 3" ]; }
            { keys = [ "alt+4" ]; commands = [ "tab_switch_index 4" ]; }
            { keys = [ "alt+5" ]; commands = [ "tab_switch_index 5" ]; }
            { keys = [ "1" ]; commands = [ "numbered_command 1" ]; }
            { keys = [ "2" ]; commands = [ "numbered_command 2" ]; }
            { keys = [ "3" ]; commands = [ "numbered_command 3" ]; }
            { keys = [ "4" ]; commands = [ "numbered_command 4" ]; }
            { keys = [ "5" ]; commands = [ "numbered_command 5" ]; }
            { keys = [ "6" ]; commands = [ "numbered_command 6" ]; }
            { keys = [ "7" ]; commands = [ "numbered_command 7" ]; }
            { keys = [ "8" ]; commands = [ "numbered_command 8" ]; }
            { keys = [ "9" ]; commands = [ "numbered_command 9" ]; }
            { keys = [ "arrow_up" ]; commands = [ "cursor_move_up" ]; }
            { keys = [ "arrow_down" ]; commands = [ "cursor_move_down" ]; }
            { keys = [ "arrow_left" ]; commands = [ "cd .." ]; }
            { keys = [ "arrow_right" ]; commands = [ "open" ]; }
            { keys = [ "\n" ]; commands = [ "open" ]; }
            { keys = [ "home" ]; commands = [ "cursor_move_home" ]; }
            { keys = [ "end" ]; commands = [ "cursor_move_end" ]; }
            { keys = [ "page_up" ]; commands = [ "cursor_move_page_up" ]; }
            { keys = [ "page_down" ]; commands = [ "cursor_move_page_down" ]; }
            { keys = [ "ctrl+u" ]; commands = [ "cursor_move_page_up 0.5" ]; }
            { keys = [ "ctrl+d" ]; commands = [ "cursor_move_page_down 0.5" ]; }
            { keys = [ "ctrl+b" ]; commands = [ "cursor_move_page_up" ]; }
            { keys = [ "ctrl+f" ]; commands = [ "cursor_move_page_down" ]; }
            { keys = [ "j" ]; commands = [ "cursor_move_down" ]; }
            { keys = [ "k" ]; commands = [ "cursor_move_up" ]; }
            { keys = [ "h" ]; commands = [ "cd .." ]; }
            { keys = [ "l" ]; commands = [ "open" ]; }
            { keys = [ "g" "g" ]; commands = [ "cursor_move_home" ]; }
            { keys = [ "G" ]; commands = [ "cursor_move_end" ]; }
            { keys = [ "shift+enter" ]; commands = [ "open_with" ]; }
            { keys = [ "H" ]; commands = [ "cursor_move_page_home" ]; }
            { keys = [ "L" ]; commands = [ "cursor_move_page_middle" ]; }
            { keys = [ "M" ]; commands = [ "cursor_move_page_end" ]; }
            { keys = [ "[" ]; commands = [ "parent_cursor_move_up" ]; }
            { keys = [ "]" ]; commands = [ "parent_cursor_move_down" ]; }
            { keys = [ "c" "d" ]; commands = [ ":cd " ]; }
            { keys = [ "d" "d" ]; commands = [ "cut_files" ]; }
            { keys = [ "y" "y" ]; commands = [ "copy_files" ]; }
            { keys = [ "y" "n" ]; commands = [ "copy_filename" ]; }
            { keys = [ "y" "." ]; commands = [ "copy_filename_without_extension" ]; }
            { keys = [ "y" "p" ]; commands = [ "copy_filepath" ]; }
            { keys = [ "y" "a" ]; commands = [ "copy_filepath --all-selected=true" ]; }
            { keys = [ "y" "d" ]; commands = [ "copy_dirpath" ]; }
            { keys = [ "p" "l" ]; commands = [ "symlink_files --relative=false" ]; }
            { keys = [ "p" "L" ]; commands = [ "symlink_files --relative=true" ]; }
            { keys = [ "delete" ]; commands = [ "delete_files" ]; }
            { keys = [ "d" "D" ]; commands = [ "delete_files" ]; }
            { keys = [ "p" "p" ]; commands = [ "paste_files" ]; }
            { keys = [ "p" "o" ]; commands = [ "paste_files --overwrite=true" ]; }
            { keys = [ "r" ]; commands = [ "rename_append" ]; }
            { keys = [ "R" ]; commands = [ "rename_prepend" ]; }
            { keys = [ "f" "t" ]; commands = [ ":touch " ]; }
            { keys = [ " " ]; commands = [ "select --toggle=true" ]; }
            { keys = [ "t" ]; commands = [ "select --all=true --toggle=true" ]; }
            { keys = [ "V" ]; commands = [ "toggle_visual" ]; }
            { keys = [ "w" ]; commands = [ "show_tasks --exit-key=w" ]; }
            { keys = [ "b" "b" ]; commands = [ "bulk_rename" ]; }
            { keys = [ "=" ]; commands = [ "set_mode" ]; }
            { keys = [ ":" ]; commands = [ ":" ]; }
            { keys = [ ";" ]; commands = [ ":" ]; }
            { keys = [ "'" ]; commands = [ ":shell " ]; }
            { keys = [ "o" ]; commands = [ ":mkdir " ]; }
            { keys = [ "c" "w" ]; commands = [ ":rename " ]; }
            { keys = [ "/" ]; commands = [ ":search " ]; }
            { keys = [ "|" ]; commands = [ ":search_inc " ]; }
            { keys = [ "\\" ]; commands = [ ":search_glob " ]; }
            { keys = [ "S" ]; commands = [ "search_fzf" ]; }
            { keys = [ "C" ]; commands = [ "subdir_fzf" ]; }
            { keys = [ "n" ]; commands = [ "search_next" ]; }
            { keys = [ "N" ]; commands = [ "search_prev" ]; }
            { keys = [ "s" "r" ]; commands = [ "sort reverse" ]; }
            { keys = [ "s" "l" ]; commands = [ "sort lexical" ]; }
            { keys = [ "s" "m" ]; commands = [ "sort mtime" ]; }
            { keys = [ "s" "n" ]; commands = [ "sort natural" ]; }
            { keys = [ "s" "s" ]; commands = [ "sort size" ]; }
            { keys = [ "s" "e" ]; commands = [ "sort ext" ]; }
            { keys = [ "m" "s" ]; commands = [ "linemode size" ]; }
            { keys = [ "m" "m" ]; commands = [ "linemode mtime" ]; }
            { keys = [ "m" "M" ]; commands = [ "linemode size | mtime" ]; }
            { keys = [ "m" "u" ]; commands = [ "linemode user" ]; }
            { keys = [ "m" "U" ]; commands = [ "linemode user | group" ]; }
            { keys = [ "m" "p" ]; commands = [ "linemode perm" ]; }
            { keys = [ "g" "r" ]; commands = [ "cd /" ]; }
            { keys = [ "g" "c" ]; commands = [ "cd ~/.config" ]; }
            { keys = [ "g" "d" ]; commands = [ "cd ~/tmp" ]; }
            { keys = [ "g" "e" ]; commands = [ "cd /etc" ]; }
            { keys = [ "g" "h" ]; commands = [ "cd ~/" ]; }
            { keys = [ "?" ]; commands = [ "help" ]; }
          ];
        };
        task_view = {
          keymap = [
            { keys = [ "arrow_up" ]; commands = [ "cursor_move_up" ]; }
            { keys = [ "arrow_down" ]; commands = [ "cursor_move_down" ]; }
            { keys = [ "home" ]; commands = [ "cursor_move_home" ]; }
            { keys = [ "end" ]; commands = [ "cursor_move_end" ]; }
            { keys = [ "j" ]; commands = [ "cursor_move_down" ]; }
            { keys = [ "k" ]; commands = [ "cursor_move_up" ]; }
            { keys = [ "g" "g" ]; commands = [ "cursor_move_home" ]; }
            { keys = [ "G" ]; commands = [ "cursor_move_end" ]; }
            { keys = [ "w" ]; commands = [ "show_tasks" ]; }
            { keys = [ "escape" ]; commands = [ "show_tasks" ]; }
          ];
        };
        help_view = {
          keymap = [
            { keys = [ "arrow_up" ]; commands = [ "cursor_move_up" ]; }
            { keys = [ "arrow_down" ]; commands = [ "cursor_move_down" ]; }
            { keys = [ "home" ]; commands = [ "cursor_move_home" ]; }
            { keys = [ "end" ]; commands = [ "cursor_move_end" ]; }
            { keys = [ "j" ]; commands = [ "cursor_move_down" ]; }
            { keys = [ "k" ]; commands = [ "cursor_move_up" ]; }
            { keys = [ "g" "g" ]; commands = [ "cursor_move_home" ]; }
            { keys = [ "G" ]; commands = [ "cursor_move_end" ]; }
            { keys = [ "w" ]; commands = [ "show_tasks" ]; }
            { keys = [ "escape" ]; commands = [ "show_tasks" ]; }
          ];
        };
      };
    };

    xdg.configFile."joshuto/file_preview.sh" = {
      source = ./file_preview.sh;
      executable = true;
    };
  };
}
