{
  inputs,
  pkgs,
  lib,
  ...
}: let
  node-image = number:
    inputs.nixos-generators.nixosGenerate {
      system = pkgs.system;
      modules = [
        {
          nixpkgs.pkgs = pkgs;
          nix.registry.nixpkgs.flake = inputs.nixpkgs;
          virtualisation.diskSize = 10 * 1024;

          node-image.number = number;
        }
        ./node-image.nix
      ];
      format = "qcow";
    };
in {
  imports = [
    inputs.nixvirt.nixosModules.default
  ];

  systemd.services.kubernetes-setup = {
    enable = true;
    unitConfig = {
      After = ["libvirtd.service"];
      Requires = ["libvirtd.service"];
    };
    wantedBy = ["multi-user.target" "libvirtd.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = let
        virsh = "${pkgs.libvirt}/bin/virsh";
      in
        lib.getExe (pkgs.writeShellScriptBin "kubernetes-setup" ''
          if [ ! -f /var/lib/kubernetes/kube-0.qcow2 ]; then
            echo "Creating new drive for kube-0"
            cp ${node-image 0}/nixos.qcow2 /var/lib/kubernetes/kube-0.qcow2
          fi
          if [ ! -f /var/lib/kubernetes/kube-1.qcow2 ]; then
            echo "Creating new drive for kube-1"
            cp ${node-image 1}/nixos.qcow2 /var/lib/kubernetes/kube-1.qcow2
          fi

          if ! ${virsh} -c qemu:///system dominfo kube-0 | grep -q 'State:.*running'; then
            ${virsh} -c qemu:///system start kube-0
          fi
          if ! ${virsh} -c qemu:///system dominfo kube-1 | grep -q 'State:.*running'; then
            ${virsh} -c qemu:///system start kube-1
          fi
        '');
    };
  };

  boot.kernelModules = ["vhost_vsock"];

  virtualisation.libvirt = {
    enable = true;
    connections."qemu:///system" = {
      domains = let
        node = number:
          inputs.nixvirt.lib.domain.templates.linux {
            name = "kube-${toString number}";
            uuid = "2904419d-b283-4cfd-9f2c-7c3713ff809${toString number}";
            memory = {
              count = 6;
              unit = "GiB";
            };
            storage_vol = "/var/lib/kubernetes/kube-${toString number}.qcow2";
            bridge_name = "br0";
            virtio_video = false;
          };
      in [
        {
          definition = inputs.nixvirt.lib.domain.writeXML (node 0);
        }
        {
          definition = inputs.nixvirt.lib.domain.writeXML (node 1);
        }
      ];
    };
  };

  # virtualisation.libvirtd.allowedBridges = ["br0"];

  persist.generated.directories = [
    {
      directory = "/var/lib/kubernetes";
      user = "root";
      group = "root";
      mode = "770";
    }
  ];
}
