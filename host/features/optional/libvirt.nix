{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.qemu
    pkgs.libvirt
    pkgs.virt-viewer
    pkgs.virt-manager
  ];

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernelModules = ["kvm-intel" "kvm-amd"];
  boot.kernelParams = [
    "intel_iommu=on" # or "amd_iommu=on"
  ];
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };

  boot.initrd.kernelModules = [
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"
  ];

  networking = {
    interfaces."br0-virtint" = {
      ipv4.addresses = [
        {
          address = "192.168.74.1";
          prefixLength = 24;
        }
      ];
      useDHCP = true;
    };
    nat = {
      enable = true;
      internalInterfaces = ["br0-virtint"];
    };
  };
}
