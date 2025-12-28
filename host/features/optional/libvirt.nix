{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.qemu
  ];

  boot.kernelModules = ["kvm-intel" "kvm-amd"];
  virtualisation.libvirtd.enable = true;
}
