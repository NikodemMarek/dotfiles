{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.wired.homeManagerModules.default
  ];

  home.packages = with pkgs; [
    libnotify
  ];
  services.wired = {
    enable = true;
  };
}
