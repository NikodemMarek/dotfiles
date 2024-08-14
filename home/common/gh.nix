{pkgs, config, ...}: {
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
    };
    extensions = [
      pkgs.gh-copilot
    ];
  };

  home = {
    shellAliases = {
      ghsg = "gh copilot suggest --target shell '$_'";
    };
    persistence."/persist/home/${config.home.username}".directories = [
      ".config/github-copilot"
      ".local/share/gh"
    ];
  };
}
