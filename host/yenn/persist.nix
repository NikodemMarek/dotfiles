{
  persist.users.nikodem = {
    data = {
      directories = [
        "projects"
        "documents"

        "vaults"
        "vms"

        "games"
      ];
    };
    generated = {
      directories = [
        # jetbrains
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

        # obsidian
        ".config/obsidian"

        # gemini
        ".gemini"

        # common
        ".config/Google"

        ".local/share/keyrings"
        ".local/share/Google"

        ".cache"

        # fun
        ".local/share/PrismLauncher"

        ".local/share/Steam"
        ".factorio"

        ".config/heroic"
      ];

      files = [
        # fish
        ".local/share/fish/fish_history"

        # sops
        ".config/sops/age/keys.txt"

        # default browser
        ".config/mimeapps.list"

        # ssh
        ".ssh/known_hosts"
      ];
    };
  };
}
