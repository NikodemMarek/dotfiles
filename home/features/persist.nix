user: {
  persist.users.${user} = {
    data = {
      directories = [
        "projects"
        "documents"

        "vaults"
        "vms"
      ];
    };
    generated = {
      directories = [
        ".config/JetBrains"

        ".local/share/JetBrains"

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

        # zen browser

        ".zen"

        # direnv

        ".local/share/direnv"

        # gh

        ".config/github-copilot"
        ".local/share/gh"

        # ssh

        ".ssh"

        # obsidian

        ".config/obsidian"

        # beeper

        ".config/Beeper"

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
