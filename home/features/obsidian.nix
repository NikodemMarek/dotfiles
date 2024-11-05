{pkgs, ...}: {
  home.packages = [pkgs.obsidian];

  persist = {
    data.directories = [
      "vaults"
    ];
    generated.directories = [
      ".config/obsidian"
    ];
  };
}
