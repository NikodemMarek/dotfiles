{
  inputs,
  pkgs,
  lib,
  ...
}: {
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
        virsh = "${pkgs.libvirt}/bin/virsh -c qemu:///system";
      in
        lib.getExe (pkgs.writeShellScriptBin "kubernetes-setup" ''
          if ! ${virsh} dominfo kube-0 | grep -q 'State:.*running'; then
            ${virsh} start kube-0
          fi
        '');
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  boot.kernelModules = ["vhost_vsock"];
  networking.firewall.interfaces."br0-virtint".allowedTCPPorts = [7878 8989];

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
            bridge_name = "br0-virtint";
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

  services.traefik.dynamicConfigOptions.http = {
    services = {
      web-forward.loadBalancer.servers = [
        {
          url = "http://192.168.74.2:80";
        }
      ];
    };
    routers = {
      subsonic = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^subsonic\..+$`)";
        service = "web-forward";
        # tls.certResolver = "letsencrypt";
      };
      jellyfin = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^jellyfin\..+$`)";
        service = "web-forward";
        # tls.certResolver = "letsencrypt";
      };
      seerr = {
        entryPoints = ["web"];
        rule = "HostRegexp(`^seerr\..+$`)";
        service = "web-forward";
        # tls.certResolver = "letsencrypt";
      };
    };
  };

  persist.generated.directories = [
    {
      directory = "/var/lib/kubernetes";
      user = "root";
      group = "root";
      mode = "770";
    }
  ];
}
