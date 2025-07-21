{
  imports = [
    (import ../features/persist.nix "fun")
  ];

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

        ".config/heroic"
      ];
    };
  };
}
