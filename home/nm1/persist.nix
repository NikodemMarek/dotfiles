{
  imports = [
    (import ../features/persist.nix "nm1")
  ];

  persist.users.nm1 = {
    generated = {
      directories = [
        ".gradle/caches/modules-2/files-2.1"

        ".config/google-chrome"
        ".cache/google-chrome"

        ".config/remmina"
        ".cache/remmina"

        ".local/share/DBeaverData"
      ];
    };
  };
}
