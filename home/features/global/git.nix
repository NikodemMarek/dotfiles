{
  programs.git = {
    enable = true;
    aliases = {
      "s" = "status";
      "b" = "branch --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(contents:subject) %(color:green)(%(committerdate:relative)) %(color:red)[%(authorname)]' --sort=-committerdate";
      "l" = "log --graph --pretty=format:'%C(yellow)%Creset %C(auto)%h%d%Creset | %C(cyan) %cr%Creset | %C(green) %cn%Creset |  %s'";
      "w" = "worktree";
      "aa" = "!git add --all && git s && :";
      "ci" = "commit -m";
      "nb" = "checkout -b";
      "sw" = "switch";
      "st" = "stash -u";
      "stp" = "stash pop";
      "std" = "stash drop";
      "ua" = "checkout HEAD --";
      "ph" = "push -u origin";
      "rst" = "reset --soft --keep HEAD^";
    };
    extraConfig = {
      init.defaultBranch = "main";
      safe.directory = "/etc/nixos";
    };
  };

  home.shellAliases = {
    g = "git";
  };
}
