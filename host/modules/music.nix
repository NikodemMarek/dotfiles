{pkgs, ...}: let
  base-path = "/home/music";

  config-beets = pkgs.writeText "config-beets.yaml" ''
    directory: ${base-path}/data
    import:
      move: true
    library: ${base-path}/musiclib.db
  '';

  anysync-config = pkgs.writeText "anysync-config.toml" ''
    port = 5060

    [sources.music]
    path = "${base-path}/data"
    actions = "get"
  '';

  nix-shell = pkgs.writeText "nix-shell.nix" ''
    {pkgs ? import <nixpkgs> {}}: let
      alias-get-single = pkgs.writeShellScriptBin "get-single"
        '''yt-dlp --default-search "https://music.youtube.com/search/?q=" --embed-metadata --embed-thumbnail -f bestaudio -x --audio-format flac -P ${base-path}/to-add --playlist-items 1 :"$1"; beet -c ${config-beets} import --quiet --singletons ${base-path}/to-add''';
    in
      pkgs.mkShell {
        packages = with pkgs; [yt-dlp beets];
        buildInputs = with pkgs; [yt-dlp beets] ++ [alias-get-single];
        shellHook = '''
          printf "\e[33m
            \e[1mget-single \"<query>\"\e[0m\e[33m  -> get single and import it to the library
          \e[0m"
        ''';
      }
  '';
in {
  users.groups.music = {};
  systemd.tmpfiles.rules = [
    "d ${base-path} 0774 root music -"
    "d ${base-path}/data 0774 root music -"
    "d ${base-path}/to-add 0774 root music -"
    "f ${base-path}/musiclib.db 0774 root music -"

    "f ${base-path}/.envrc 0444 root root - use nix ${nix-shell}" # enable direnv shell
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
