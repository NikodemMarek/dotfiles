{ config, pkgs, lib, email, name, ... }: {
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
}
