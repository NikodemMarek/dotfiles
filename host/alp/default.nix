# Generate iso with this: nix shell nixpkgs#nixos-generators --command "nixos-generate --format iso --configuration ./host/alp/default.nix -o result".
{
  pkgs,
  modulesPath,
  lib,
  ...
}: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  services.tailscale = {
    enable = true;
    # Generate the key in tailscale console, Settings > Keys.
    authKeyFile = ./key;
  };
  services.openssh.enable = true;

  nix.settings.trusted-users = ["maintenance" "@wheel"];
  users.users = {
    root = {
      password = lib.mkForce "nixos";
      openssh.authorizedKeys.keyFiles = [
        ../yenn/user_nikodem_ssh_id_ed25519.pub
      ];
    };
    nixos = {
      password = lib.mkForce "nixos";
      openssh.authorizedKeys.keyFiles = [
        ../yenn/user_nikodem_ssh_id_ed25519.pub
      ];
    };
  };

  boot.kernelPackages = pkgs.linuxPackages_6_18;
  boot.supportedFilesystems = lib.mkForce ["btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" "zfs"];
}
