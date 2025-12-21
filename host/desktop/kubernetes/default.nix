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

  virtualisation.libvirtd.enable = true;
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
            bridge_name = "virbr1";
          };
      in [
        {
          definition = inputs.nixvirt.lib.domain.writeXML (node 0);
        }
        {
          definition = inputs.nixvirt.lib.domain.writeXML (node 1);
        }
      ];
      networks = [
        {
          definition = inputs.nixvirt.lib.network.writeXML (inputs.nixvirt.lib.network.templates.bridge
            {
              name = "kube-bridge";
              bridge_name = "virbr1";
              uuid = "d2102492-5797-429b-aa31-96b1b0d6f8e8";
              subnet_byte = 74;
              dhcp_hosts = [
                {
                  name = "kube-0";
                  mac = "52:54:00:74:10:01";
                  ip = "192.168.74.2";
                }
                {
                  name = "kube-1";
                  mac = "52:54:00:74:10:02";
                  ip = "192.168.74.3";
                }
              ];
            });
          active = true;
        }
      ];
    };
  };

  networking = {
    bridges."br2".interfaces = ["enp5s0"];
    interfaces.br2 = {
      ipv4.addresses = [
        {
          address = "192.168.74.1";
          prefixLength = 24;
        }
      ];
    };
    interfaces.br2.useDHCP = true;
  };

  virtualisation.libvirtd.allowedBridges = ["br2"];

  persist.generated.directories = [
    {
      directory = "/var/lib/kubernetes";
      user = "root";
      group = "root";
      mode = "770";
    }
  ];
}
