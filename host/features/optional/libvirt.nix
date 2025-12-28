{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.qemu
    pkgs.libvirt
    pkgs.virt-viewer
  ];

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernelModules = ["kvm-intel" "kvm-amd"];
  virtualisation.libvirtd.enable = true;

  networking = {
    interfaces.br0 = {
      ipv4.addresses = [
        {
          address = "192.168.74.1";
          prefixLength = 24;
        }
      ];
      useDHCP = true;
    };
    nat = {
      internalInterfaces = ["br0"];
      enable = true;
    };
  };
}
