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
      type = types.int;
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
  };
}
