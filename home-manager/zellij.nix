{ config, pkgs, lib, ... }: {
  imports = [
    ./gitui.nix
  ];

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
}
