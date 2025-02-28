{
  persist.users.fun = {
    data = {
      directories = [
        "games"
      ];
    };
    generated = {
      directories = [
        ".local/share/PrismLauncher"

        ".local/share/Steam"
        ".factorio"

        # neovim

        ".local/share/nvim"

        ".npm"
        ".cargo"
        ".java"
        ".gradle"
        ".m2"
        ".android"

        # docker

        ".docker"
        ".dockercache"

        # fish

        ".local/share/zoxide"

        # mozilla

        ".mozilla"

        # direnv

        ".local/share/direnv"

        # gh

        ".config/github-copilot"
        ".local/share/gh"

        # ssh

        ".ssh"

        # common

        ".config/Google"

        ".local/share/keyrings"
        ".local/share/Google"

        ".cache"
      ];

      files = [
        # fish

        ".local/share/fish/fish_history"

        # sops

        ".config/sops/age/keys.txt"
      ];
    };
  };
}
