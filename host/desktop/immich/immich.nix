{
  services.immich = {
    enable = true;
    port = 2283;
    openFirewall = true;
    mediaLocation = "/mnt/photos";
    group = "photos";
    settings = {
      reverseGeocoding.enabled = true;
      newVersionCheck.enabled = false;
      server = {
        externalDomain = "";
      };
      storageTemplate = {
        enabled = true;
        hashVerificationEnabled = true;
        template = "{{y}}/{{MMM}}/{{dd}}/{{filename}}";
      };
    };
    environment = {
      IMMICH_TELEMETRY_INCLUDE = "all";
    };
  };
}
