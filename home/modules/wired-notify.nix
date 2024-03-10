{pkgs, ...}: {
  home.packages = with pkgs; [
    libnotify
  ];
  services.wired = {
    enable = true;
  };
}
