{
  persist.users.nm1 = {
    data = {
      directories = [
        "projects"
        "documents"
        "screenshots"
      ];
    };
    generated = {
      directories = [
        ".config/JetBrains"

        ".local/share/JetBrains"
        ".gradle/caches/modules-2/files-2.1"

        ".config/google-chrome"
        ".cache/google-chrome"

        ".config/remmina"
        ".cache/remmina"

        ".local/share/DBeaverData"

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
