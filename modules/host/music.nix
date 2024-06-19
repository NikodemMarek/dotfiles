{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.music;

  config-beets = pkgs.writeText "config-beets.yaml" ''
    directory: ${cfg.path}/data
    import:
      move: true
      duplicate_action: merge
    library: ${cfg.path}/musiclib.db
    paths:
      default: $albumartist/$album%aunique{}/$title
      singleton: singles/$artist/$title
  '';

  # TODO: Turn this into a separate module
  anysync-config = pkgs.writeText "anysync-config.toml" ''
    port = 5060

    [sources.music]
    path = "${cfg.path}/data"
    actions = "get"
  '';

  nix-shell = pkgs.writeText "nix-shell.nix" ''
    {pkgs ? import <nixpkgs> {}}: let
      alias-beets = pkgs.writeShellScriptBin "b" "beet -c ${config-beets} $@";

      alias-get-single = pkgs.writeShellScriptBin "get-single"
        '''yt-dlp --default-search "https://music.youtube.com/search/?q=" --embed-metadata --embed-thumbnail -f bestaudio -x --audio-format flac -P ${cfg.path}/to-add --playlist-items 1 :"$1"; beet -c ${config-beets} import --quiet --singletons ${cfg.path}/to-add''';
      alias-get-playlist-url = pkgs.writeShellScriptBin "get-playlist-url"
        '''yt-dlp --embed-metadata --embed-thumbnail -f bestaudio -x --audio-format flac -P ${cfg.path}/to-add :"$1"; beet -c ${config-beets} import --quiet --group-albums ${cfg.path}/to-add''';
    in
      pkgs.mkShell {
        packages = with pkgs; [yt-dlp beets];
        buildInputs = with pkgs; [yt-dlp beets] ++ [alias-beets alias-get-single alias-get-playlist-url];
        shellHook = '''
          printf "\e[33m
            \e[1mget-single \"<query>\"    \e[0m\e[33m  -> get single and import it to the library
            \e[1mget-playlist-url \"<url>\"\e[0m\e[33m  -> get playlist and import it to the library
          \e[0m"
        ''';
      }
  '';
in {
  options.services.music = {
    enable = lib.mkEnableOption "Enable music service";

    path = lib.mkOption {
      type = lib.types.str;
      default = "/home/music";
      description = "Path to music library";
    };

    anysync = lib.mkEnableOption "Enable anysync server";

    persistent = lib.mkEnableOption "Enable if persistence is needed";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."users/music/password" = {
      sopsFile = ../../setups/${config.networking.hostName}/secrets.yaml;
      neededForUsers = true;
    };

    users = {
      groups.music = {};
      users.music = {
        isNormalUser = true;
        uid = 1100;
        createHome = false;
        hashedPasswordFile = config.sops.secrets."users/music/password".path;
        extraGroups = ["music"];

        # TODO: change this to custom shell
        useDefaultShell = false;
        shell = pkgs.bashInteractive;
      };
    };
    systemd.tmpfiles.rules = [
      "d ${cfg.path} 0774 music music -"
      "d ${cfg.path}/data 0774 music music -"
      "d ${cfg.path}/to-add 0774 music music -"
      "f ${cfg.path}/musiclib.db 0774 music music -"

      "f ${cfg.path}/.envrc 0444 music music - use nix ${nix-shell}" # enable direnv shell
    ];

    systemd.services.anysync-music = lib.mkIf cfg.anysync {
      enable = true;
      description = "anysync server with music";

      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.anysync}/bin/anysync-server -c ${anysync-config}";
        Restart = "always";
      };
    };

    environment.persistence."/persist" = lib.mkIf cfg.persistent {
      directories = [
        {
          directory = cfg.path;
          user = "music";
          group = "music";
          mode = "u=rwx,g=rwx,o=rx";
        }
        {
          directory = "${cfg.path}/data";
          user = "music";
          group = "music";
          mode = "u=rwx,g=rwx,o=rx";
        }
        {
          directory = "${cfg.path}/to-add";
          user = "music";
          group = "music";
          mode = "u=rwx,g=rwx,o=rx";
        }
      ];
      files = [
        {
          file = "${cfg.path}/musiclib.db";
          parentDirectory = {mode = "u=rwx,g=rwx,o=rx";};
        }
        {
          file = "${cfg.path}/.envrc";
          parentDirectory = {mode = "u=rx,g=rx,o=rx";};
        }
      ];
    };
  };
}
