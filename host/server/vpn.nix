{config, ...}: {
  networking.firewall.allowedUDPPorts = [4500];
  networking.useNetworkd = true;

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
  systemd.network = {
    enable = true;
    netdevs = {
      "50-wg1" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg1";
          MTUBytes = "1420";
        };
        wireguardConfig = {
          PrivateKeyFile = config.sops.secrets."wireguard/private_key".path;
          ListenPort = 4500;
        };
        wireguardPeers = [
          {
            PublicKey = "p5wyBizKMNg89ctyKTYTF21M2VeBbPiG2JwNpMtNo2g=";
            AllowedIPs = ["10.48.72.2/32" "fd48:a8a8:ef08::2/64"];
          }
          {
            PublicKey = "Tg9drcQ0ibqvqRxbulVRyjj8KrnnntkLevaSltFV3X0=";
            AllowedIPs = "10.48.72.3/32";
          }
          {
            PublicKey = "/C8RaJEcGCRtvgEQRyaEtKnoQr/gPJ8B6h7F5GV3iDA=";
            AllowedIPs = "10.48.72.4/32";
          }
          {
            PublicKey = "6rO5pQ1baGoT8oC0JB/v5kHg293QjfROQ+X7NHOmX1M=";
            AllowedIPs = "10.48.72.5/32";
          }
          {
            PublicKey = "me3BCekw0xEPlLTu5M54L1xCgXGEM2Eebki6q7lwJH4=";
            AllowedIPs = "10.48.72.6/32";
          }
          {
            PublicKey = "SN3pO49OziTSushDAWy8H06xgCDus2qD5H+d06dbqS0=";
            AllowedIPs = "10.48.72.7/32";
          }
          {
            PublicKey = "MQnQ3nwmBzkigiHiLq+tRqjZ4h8lsXP6/wG9FXeaa34=";
            AllowedIPs = "10.48.72.8/32";
          }
          {
            PublicKey = "GTfy89m7TeBdQPM7qtD5/SN786QoB79e0QW7TqxkyHY=";
            AllowedIPs = "10.48.72.9/32";
          }
          {
            PublicKey = "IwpTYBvYA6iAOYMWGsyvRE7P7cYv6mu0pld7/W5sDhA=";
            AllowedIPs = "10.48.72.10/32";
          }
          {
            PublicKey = "FPWsIjDtuflHz6++j3sH6SViQ87Ol18x2y3WGB2yOCs=";
            AllowedIPs = "10.48.72.11/32";
          }
          {
            PublicKey = "QmFqu7tvtfC3v4kH5Tpvn3jNpXPFl82VrXwAwtM79jw=";
            AllowedIPs = "10.48.72.12/32";
          }
          {
            PublicKey = "h7OO11StOfZ7iMeSrwDhs/c8tMdSE1c+MZD1tteF01o=";
            AllowedIPs = "10.48.72.13/32";
          }
          {
            PublicKey = "sSPTiYjErVEwend0B+pnCF1oqyqQ/J2g9ztr5jARTTk=";
            AllowedIPs = "10.48.72.14/32";
          }
          {
            PublicKey = "7JGzIjaibKBbc6CxHpNwroPqeu51AL58507cV84VGyY=";
            AllowedIPs = "10.48.72.15/32";
          }
          {
            PublicKey = "YYgU4VT+fAMNSFZnTB0RcKvmLkUe0I1SvP3PduNzNn4=";
            AllowedIPs = "10.48.72.16/32";
          }
          {
            PublicKey = "o+QVtYIKImhyAZzeBgQdGEj37E5I5d+laz97OmpUGiY=";
            AllowedIPs = "10.48.72.17/32";
          }
          {
            PublicKey = "KJXRVrPEYmy8kdBU2hMPvgEhzdvMlRs4E2IXZ3gyEBY=";
            AllowedIPs = "10.48.72.18/32";
          }
          {
            PublicKey = "nPWGMjWfu96pYeYRmeS+RYtIrXATaGBxKaUXLT99Xi4=";
            AllowedIPs = "10.48.72.19/32";
          }
          {
            PublicKey = "9k/CpMXANawwGAZZ97nEa0xVhKF6vWMEpqjP0va7Kkk=";
            AllowedIPs = "10.48.72.20/32";
          }
          {
            PublicKey = "G/vrSge8Apb9qeq0PndJeBU3f19XLPYYFKgPpLReshM=";
            AllowedIPs = "10.48.72.21/32";
          }
        ];
      };
    };

    networks = {
      "50-wg1" = {
        matchConfig.Name = "wg1";
        address = ["10.48.72.1/24" "fd48:a8a8:ef08::1/64"];
        networkConfig = {
          IPMasquerade = "both";
          IPv4Forwarding = true;
          IPv6Forwarding = true;
        };
      };
    };
  };
}
