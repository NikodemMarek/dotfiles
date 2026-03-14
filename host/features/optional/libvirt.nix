{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.qemu
    pkgs.libvirt
    pkgs.virt-viewer
    pkgs.virt-manager
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
  boot.kernelModules = ["kvm-amd"];
  boot.kernelParams = ["amd_iommu=on"];
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
    nat = {
      enable = true;
      internalInterfaces = ["virbr0"];
    };
  };

  persist.generated.directories = [
    {
      directory = "/var/lib/libvirt/";
      user = "root";
      group = "root";
    }
  ];
}
