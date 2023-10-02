{ ... }: {
  programs.starship.enable = true;

  programs.zoxide.enable = true;

  programs.zellij.enable = true;
  xdg.configFile."zellij/layouts/project.kdl".text = ''
    layout {
        tab name="neovim" focus=true {
            floating_panes {
                pane name="run"
            }
            pane command="nvim"
        }
        tab name="git" {
            pane command="gitui"
        }
    }
  '';

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Fully clear console.
      function fish_user_key_bindings
        bind \cl 'clear; commandline -f repaint'
      end

      function fish_greeting
      end
    '';
    shellAliases = {
      zop = "zellij -l 'project'";
    };
  };
}
