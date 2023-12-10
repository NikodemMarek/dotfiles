{ inputs, outputs, lib, config, pkgs, ... }: {
  fileSystems = {
    "/".options = [ "compress=lzo" ];
    "/home".options = [ "compress=lzo" ];
    "/nix".options = [ "compress=lzo" "noatime" ];
  };

  swapDevices = [{
    device = "/swapfile";
    size = 38 * 1024;
  }];
  boot.kernelParams = [ "resume_offset=25928960" ];
  boot.resumeDevice = "/dev/disk/by-uuid/fc60a589-f4e6-4f9e-b149-b372221e824b";
  security.protectKernelImage = false;
}
