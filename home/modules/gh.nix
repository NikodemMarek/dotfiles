{
  config,
  pkgs,
  settings,
  ...
}: {
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
    };
    extensions = [
      pkgs.gh-copilot
    ];
  };

  home.shellAliases = {
    ghsg = "gh copilot suggest --target shell '$_'";
  };
}
