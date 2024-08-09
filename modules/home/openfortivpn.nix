{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.openfortivpn;

  inherit (lib) types;
in {
  options.services.openfortivpn = {
    enable = lib.mkEnableOption "Enable openfortivpn";

    host = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "VPN gateway host";
    };

    port = lib.mkOption {
      type = types.either types.str types.int;
      default = 8443;
      description = "VPN gateway port";
    };

    username = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "VPN username";
    };

    password = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "VPN password";
    };

    realm = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "VPN realm";
    };

    trusted-cert = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "VPN trusted certificate";
    };

    user-cert = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "User certificate";
    };
    user-key = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "User key";
    };

    extraConfig = lib.mkOption {
      type = types.str;
      default = "";
      description = "Extra configuration options";
    };

    autorun = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Run openfortivpn on system startup";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.openfortivpn];

    xdg.configFile."openfortivpn/config".text = ''
      ${lib.optionalString (cfg.host != null) "host = ${toString cfg.host}"}
      port = ${toString cfg.port}
      ${lib.optionalString (cfg.realm != null) "realm = ${cfg.realm}"}

      ${lib.optionalString (cfg.username != null) "username = ${cfg.username}"}
      ${lib.optionalString (cfg.password != null) "password = ${cfg.password}"}

      ${lib.optionalString (cfg.trusted-cert != null) "trusted-cert = ${cfg.trusted-cert}"}

      ${lib.optionalString (cfg.user-cert != null) "user-cert = ${cfg.user-cert}"}
      ${lib.optionalString (cfg.user-key != null) "user-key = ${cfg.user-key}"}

      ${cfg.extraConfig}
    '';

    systemd.user.services.openfortivpn = lib.mkIf cfg.autorun {
      Install = {
        WantedBy = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = let
          openfortivpn-askpass = pkgs.writeShellScriptBin "openfortivpn-askpass" "${pkgs.zenity}/bin/zenity --password";
        in "${pkgs.writeShellScriptBin "openfortivpn-execstart" ''
          TOKEN=$(${pkgs.zenity}/bin/zenity --entry --text "podaj token")

          echo token: $TOKEN

          echo $TOKEN | SUDO_ASKPASS=${openfortivpn-askpass}/bin/openfortivpn-askpass /run/wrappers/bin/sudo -A ${pkgs.openfortivpn}/bin/openfortivpn --config ${config.home.homeDirectory}/${config.xdg.configFile."openfortivpn/config".target}
        ''}/bin/openfortivpn-execstart";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
