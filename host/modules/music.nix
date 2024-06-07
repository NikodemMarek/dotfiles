{
  config,
  pkgs,
  hostname,
  ...
}: let
  base-path = "/home/music";

  config-beets = pkgs.writeText "config-beets.yaml" ''
    directory: ${base-path}/data
    import:
      move: true
      duplicate_action: merge
    library: ${base-path}/musiclib.db
    paths:
      default: $albumartist/$album%aunique{}/$title
      singleton: singles/$artist/$title
  '';

  anysync-config = pkgs.writeText "anysync-config.toml" ''
    port = 5060

    [sources.music]
    path = "${base-path}/data"
    actions = "get"
  '';

  nix-shell = pkgs.writeText "nix-shell.nix" ''
    {pkgs ? import <nixpkgs> {}}: let
      alias-beets = pkgs.writeShellScriptBin "b" "beet -c ${config-beets} $@";

      alias-get-single = pkgs.writeShellScriptBin "get-single"
        '''yt-dlp --default-search "https://music.youtube.com/search/?q=" --embed-metadata --embed-thumbnail -f bestaudio -x --audio-format flac -P ${base-path}/to-add --playlist-items 1 :"$1"; beet -c ${config-beets} import --quiet --singletons ${base-path}/to-add''';
      alias-get-playlist-url = pkgs.writeShellScriptBin "get-playlist-url"
        '''yt-dlp --embed-metadata --embed-thumbnail -f bestaudio -x --audio-format flac -P ${base-path}/to-add :"$1"; beet -c ${config-beets} import --quiet --group-albums ${base-path}/to-add''';
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
  sops.secrets."users/music/password" = {
    sopsFile = ../${hostname}/secrets.yaml;
    neededForUsers = true;
  };

  users.groups.music = {};
  users.users.music = {
    isNormalUser = true;
    uid = 1100;
    createHome = false;
    hashedPasswordFile = config.sops.secrets."users/music/password".path;
    extraGroups = ["music"];

    # TODO: change this to custom shell
    useDefaultShell = false;
    shell = pkgs.bashInteractive;
  };
  systemd.tmpfiles.rules = [
    "d ${base-path} 0774 music music -"
    "d ${base-path}/data 0774 music music -"
    "d ${base-path}/to-add 0774 music music -"
    "f ${base-path}/musiclib.db 0774 music music -"

    "f ${base-path}/.envrc 0444 music music - use nix ${nix-shell}" # enable direnv shell
  ];

  systemd.services.anysync-music = {
    enable = true;
    description = "anysync server with music";

    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.anysync}/bin/anysync-server -c ${anysync-config}";
      Restart = "always";
    };
  };
}
