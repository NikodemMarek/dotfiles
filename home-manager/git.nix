{ config, pkgs, lib, email, name, ... }: {
  extraPkgs = [];

  module = { config, ... }: {
    programs.git = {
      enable = true;
      aliases = {
        "s" = "status";
        "b" = "branch --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(contents:subject) %(color:green)(%(committerdate:relative)) %(color:red)[%(authorname)]' --sort=-committerdate";
        "l" = "log --graph --pretty=format:'%C(yellow)%Creset %C(auto)%h%d%Creset | %C(cyan) %cr%Creset | %C(green) %cn%Creset |  %s'";
        "u" = "!git checkout HEAD -- && git s &&;:";
        "aa" = "!git add . && git s &&;:";
        "ci" = "commit -m";
        "nb" = "!git branch $1 && git switch $1 && git b &&;:";
        "sw" = "!sh -c 'git switch $1 && git b' -";
        "st" = "!git stash && git s &&;:";
        "ua" = "checkout HEAD --";
        "ph" = "push -u origin";
        "stp" = "!git stash pop && git s &&;:";
        "rst" = "reset --soft --keep HEAD^";
        "logc" = "!git log --pretty=format:'- %h : %ae : %ad : %s' --date=format:'%Y-%m-%d %H:%M:%S' --author='${email}' --since=$1 --all --no-merges &&;:";
      };
      userEmail = email;
      userName = name;
      extraConfig = {
        init = {
          defaultBranch = "main";
        };
        safe = {
	      directory = "/dotfiles";
        };
      };
    };

    programs.gitui.enable = true;
    programs.gitui.theme = ''
      (
          selected_tab: Reset,
          command_fg: Rgb(205, 214, 244),
          selection_bg: Rgb(88, 91, 112),
          selection_fg: Rgb(205, 214, 244),
          cmdbar_bg: Rgb(24, 24, 37),
          cmdbar_extra_lines_bg: Rgb(24, 24, 37),
          disabled_fg: Rgb(127, 132, 156),
          diff_line_add: Rgb(166, 227, 161),
          diff_line_delete: Rgb(243, 139, 168),
          diff_file_added: Rgb(249, 226, 175),
          diff_file_removed: Rgb(235, 160, 172),
          diff_file_moved: Rgb(203, 166, 247),
          diff_file_modified: Rgb(250, 179, 135),
          commit_hash: Rgb(180, 190, 254),
          commit_time: Rgb(186, 194, 222),
          commit_author: Rgb(116, 199, 236),
          danger_fg: Rgb(243, 139, 168),
          push_gauge_bg: Rgb(137, 180, 250),
          push_gauge_fg: Rgb(30, 30, 46),
          tag_fg: Rgb(245, 224, 220),
          branch_fg: Rgb(148, 226, 213)
      )
    '';
  };
}
