{
  programs.git = {
    enable = true;
    settings = {
      alias = {
        "s" = "status --short";
        "b" = "branch --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(contents:subject) %(color:green)(%(committerdate:relative)) %(color:red)[%(authorname)]' --sort=-committerdate";
        "l" = "log --graph --pretty=format:'%C(yellow)%Creset %C(auto)%h%d%Creset | %C(cyan) %cr%Creset | %C(green) %cn%Creset |  %s'";
        "ci" = "commit -m";
        "nb" = "checkout -b";
        "sw" = "switch";
        "st" = "stash -u";
        "stp" = "stash pop";
        "ph" = "push -u origin";
      };
      safe.directory = "/etc/nixos";
      init.defaultBranch = "main";
    };
  };

  home.shellAliases = {
    g = "git";
  };
}
