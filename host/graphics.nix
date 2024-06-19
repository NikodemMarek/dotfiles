{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    mesa
  ];

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };
}
