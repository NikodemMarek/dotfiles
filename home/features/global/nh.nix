{pkgs, ...}: {
  home.packages = with pkgs; [
    nh
  ];

  home.shellAliases = {
    ns = "nh search $1";
  };
}
