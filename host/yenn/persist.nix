{
  persist.users.nikodem = {
    data = {
      directories = [
        "projects"
        "vault"
        "games"
      ];
    };
    generated = {
      directories = [
        ".cache"

        ".config/obsidian"
        ".config/Google"
        ".config/JetBrains"
        ".config/heroic"

        ".local/share/zoxide"
        ".local/share/direnv"
        ".local/share/keyrings"
        ".local/share/Google"
        ".local/share/.gemini"
        ".local/share/JetBrains"
        ".local/share/nvim"
        ".local/share/PrismLauncher"
        ".local/share/Steam"

        # TODO: For relocation
        ".npm"
        ".cargo"
        ".java"
        ".gradle"
        ".m2"
        ".android"
        ".docker"
        ".dockercache"
        ".mozilla"
        ".zen"
        ".factorio"
      ];

      files = [
        ".config/sops/age/keys.txt"
        ".config/mimeapps.list"

        ".local/share/fish/fish_history"

        ".ssh/known_hosts"
      ];
    };
  };
}
