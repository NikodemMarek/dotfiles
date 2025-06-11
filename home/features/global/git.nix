{pkgs, ...}: {
  programs.git = {
    enable = true;
    aliases = {
      "s" = "status --short";
      "b" = "branch --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(contents:subject) %(color:green)(%(committerdate:relative)) %(color:red)[%(authorname)]' --sort=-committerdate";
      "l" = "log --graph --pretty=format:'%C(yellow)%Creset %C(auto)%h%d%Creset | %C(cyan) %cr%Creset | %C(green) %cn%Creset |  %s'";
      "w" = "worktree";
      "aa" = "!git add --all && git s && :";
      "ci" = "commit -m";
      "nb" = "checkout -b";
      "sw" = "switch";
      "ssw" = "!git add --all && git commit -m 'WIP' && git switch && :";
      "st" = "stash -u";
      "stp" = "stash pop";
      "std" = "stash drop";
      "ua" = "checkout HEAD --";
      "ph" = "push -u origin";
      "rst" = "reset --soft --keep HEAD^";
    };
    hooks = {
      post-checkout = pkgs.writeShellScript "post-checkout" ''
        # This Git hook runs after 'git checkout' or 'git switch'.
        # It checks if the first commit in the current branch's history is named "WIP".
        # If it is, it undoes that commit and places its changes back into the stage.

        old_head="$1"
        new_head="$2"
        is_branch_checkout="$3"

        if [ "$is_branch_checkout" = "1" ]; then
            first_commit_message=$(git log --reverse --oneline --max-count=1 | sed -E 's/^[0-9a-f]+ (.*)/\1/')

            if [[ "$first_commit_message" == "WIP"* ]]; then
                echo "Found 'WIP' as the first commit message. Undoing commit and moving changes to stage..."

                git reset HEAD^ --soft

                if [ $? -eq 0 ]; then
                    echo "Successfully undid 'WIP' commit. Changes are now in the staging area."
                    git status --short
                else
                    echo "Failed to undo 'WIP' commit. Please check your Git history."
                fi
            fi
        fi
      '';
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
