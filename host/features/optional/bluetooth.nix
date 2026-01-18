{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  persist.generated.directories = [
    "/var/lib/bluetooth"
  ];
}
