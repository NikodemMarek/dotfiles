{pkgs, ...}: let
  config-beets = pkgs.writeText "config-beets.yaml" ''
    directory: /home/music/data
    import:
      move: true
    library: /home/music/musiclib.db
  '';
  polaris-docker-compose = pkgs.writeText "polaris-docker-compose.yml" ''
    services:
      polaris:
        image: ogarcia/polaris
        container_name: polaris
        ports:
          - "5050:5050"
        user: ":991"
        volumes:
          - /home/music/data:/music
          - /home/music/polaris/cache:/var/cache/polaris
          - /home/music/polaris/data:/var/lib/polaris
        restart: unless-stopped
  '';

  nix-shell = pkgs.writeText "nix-shell.nix" ''
    {pkgs ? import <nixpkgs> {}}: let
      alias-polaris-start = pkgs.writeShellScriptBin "polaris-start"
        '''docker compose -f ${polaris-docker-compose} up -d''';

      alias-get-single = pkgs.writeShellScriptBin "get-single"
        '''yt-dlp --default-search "https://music.youtube.com/search/?q=" --embed-metadata --embed-thumbnail -f bestaudio -x --audio-format flac -P /home/music/to-add --playlist-items 1 :"$1"; beet -c ${config-beets} import --quiet --singletons /home/music/to-add''';
    in
      pkgs.mkShell {
        packages = with pkgs; [yt-dlp beets];
        buildInputs = with pkgs; [yt-dlp beets] ++ [alias-get-single alias-polaris-start];
        shellHook = '''
          printf "\e[33m
            \e[1mpolaris-start\e[0m\e[33m         -> start polaris container
            \e[1mget-single \"<query>\"\e[0m\e[33m  -> get single and import it to the library
          \e[0m"
        ''';
      }
  '';
in {
  users.groups.music = {};
  systemd.tmpfiles.rules = [
    "d /home/music 0774 root music -"
    "d /home/music/data 0774 root music -"
    "d /home/music/to-add 0774 root music -"
    "f /home/music/musiclib.db 0774 root music -"

    "d /home/music/polaris 0774 root music -"
    "d /home/music/polaris/cache 0774 root music -"
    "d /home/music/polaris/data 0774 root music -"

    "f /home/music/.envrc 0444 root root - use nix ${nix-shell}" # enable direnv shell
  ];
}
