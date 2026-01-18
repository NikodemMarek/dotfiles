{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.hardware.nixosModules.framework-amd-ai-300-series

    (import ../features/disko/luks-btrfs-persistence-swapfile.nix {
      device = "/dev/nvme0n1";
      swap = 24;
    })
  ];

  nixpkgs.hostPlatform.system = "x86_64-linux";
  hardware = {
    cpu.amd.updateMicrocode = true;
    enableAllFirmware = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
  powerManagement.cpuFreqGovernor = "ondemand";
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    initrd = {
      availableKernelModules = [
        "nvme"
        "btmtk"
        "xhci_pci"
        "thunderbolt"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = ["kvm-amd"];
    };
  };
  security.rtkit.enable = true;
}
