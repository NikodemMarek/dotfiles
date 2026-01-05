{
  services.tailscale.enable = true;

  persist.generated.directories = [
    {
      directory = "/var/lib/tailscale";
      user = "root";
      group = "root";
      mode = "700";
    }
  ];
}
