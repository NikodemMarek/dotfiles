{ inputs, outputs, lib, config, pkgs, ... }: {
  fileSystems = {
    "/".options = [ "compress=lzo" ];
    "/home".options = [ "compress=lzo" ];
    "/nix".options = [ "compress=lzo" "noatime" ];
  };

  swapDevices = [{
    device = "/swapfile";
    size = 15 * 1024;
  }];
  boot.kernelParams = [ "resume_offset=25442627" ];
  boot.resumeDevice = "/dev/disk/by-uuid/b537105a-8de8-4724-807c-039e5b23f3bb";

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
