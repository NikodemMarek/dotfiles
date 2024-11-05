{pkgs, ...}: {
  users.groups.openfortivpn = {};

  security.sudo = {
    extraRules = [
      {
        commands = [
          {
            command = "${pkgs.openfortivpn}/bin/openfortivpn";
            options = ["NOPASSWD"];
          }
        ];
        groups = ["openfortivpn"];
      }
    ];
  };
}
