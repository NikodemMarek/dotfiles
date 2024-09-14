{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    mesa
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
