# Create 2 files in the host directory, under the hostname of the server:
# - syncthing_cert.pem - the certificate file
# - syncthing_key.pem - the key file
{config, ...}: {
  sops.secrets = {
    "syncthing/cert" = {
      sopsFile = ../../${config.networking.hostName}/syncthing_cert.pem;
      format = "binary";
    };
    "syncthing/key" = {
      sopsFile = ../../${config.networking.hostName}/syncthing_key.pem;
      format = "binary";
    };
  };

  # services.syncthing = {
  #   enable = true;
  #   openDefaultPorts = false;
  #   key = config.sops.secrets."syncthing/key".path;
  #   cert = config.sops.secrets."syncthing/cert".path;
  #   overrideDevices = true;
  #   overrideFolders = true;
  #   settings = {
  #     options = {
  #       urAccepted = 1;
  #     };
  #     devices = {
  #       "pixel-6a".id = "L7IXLIC-DU3D4MJ-OVOXKBW-D5M2AW5-3JWOFF4-X43JUPT-JN3XWZL-2FNL6QT";
  #       "tablet".id = "SCFNK0Z-UDF56C2-26ZS36D-A2PNTWO-K06IC55-0QGWCTN-MLNQBND-PXD8JQX";
  #     };
  #     folders = {
  #       "obsidian::main" = {
  #         label = "obsidian::main";
  #         path = "${config.users.users.nikodem.home}/vaults/main";
  #         devices = ["pixel-6a" "tablet"];
  #         # copyOwnershipFromParent = true;
  #         # versioning = {
  #         #   type = "simple";
  #         #   params = {
  #         #     keep = "5";
  #         #   };
  #         # };
  #       };
  #     };
  #   };
  # };

  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

  networking.firewall.allowedTCPPorts = [22067 22070];
  networking.firewall.allowedUDPPorts = [22000 21027];
}
